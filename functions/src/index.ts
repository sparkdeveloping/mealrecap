import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { createHash, randomUUID } from "crypto";
import { GoogleGenAI } from "@google/genai";

initializeApp({ storageBucket: "food-sbj.appspot.com" });

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
const USDA_API_KEY = defineSecret("USDA_API_KEY");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const region = "us-central1";

// Firebase Storage bucket verified with `gcloud storage buckets list --project=food-sbj`.
// Do not use food-sbj.firebasestorage.app here; Admin SDK and iOS Storage SDK need the real GCS bucket.
const storageBucketName = process.env.MEALRECAP_STORAGE_BUCKET || "food-sbj.appspot.com";

function defaultBucket() {
  return getStorage().bucket(storageBucketName);
}

function firebaseMediaURL(bucketName: string, path: string, token?: string): string {
  const base = `https://firebasestorage.googleapis.com/v0/b/${encodeURIComponent(bucketName)}/o/${encodeURIComponent(path)}?alt=media`;
  return token ? `${base}&token=${encodeURIComponent(token)}` : base;
}


type RequestLog = {
  id: string;
  endpoint: string;
  startedAt: number;
};

function requestID(): string {
  return createHash("sha256").update(`${Date.now()}-${Math.random()}`).digest("hex").slice(0, 8).toUpperCase();
}

function logStep(ctx: RequestLog, step: string, details?: Record<string, unknown>) {
  const elapsedMs = Date.now() - ctx.startedAt;
  console.log(`[${ctx.id}] ${ctx.endpoint} ${step}`, { elapsedMs, ...(details ?? {}) });
}

function logError(ctx: RequestLog, step: string, error: unknown, details?: Record<string, unknown>) {
  const elapsedMs = Date.now() - ctx.startedAt;
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[${ctx.id}] ${ctx.endpoint} ${step}`, { elapsedMs, message, ...(details ?? {}) });
}

type MealType = "breakfast" | "lunch" | "dinner" | "snack" | "dessert" | "drink" | "unknown";

type NutritionHint = {
  source: "usda" | "openfoodfacts";
  name: string;
  caloriesPer100g?: number | null;
  proteinPer100g?: number | null;
  carbsPer100g?: number | null;
  fatPer100g?: number | null;
};

type MealItem = {
  id: string;
  name: string;
  estimatedGrams: number | null;
  servingDescription: string | null;
  calories: number;
  protein: number | null;
  carbs: number | null;
  fat: number | null;
  confidence: number;
};

type MealAnalysis = {
  title: string;
  mealType: MealType;
  items: MealItem[];
  totalCalories: number;
  macros: { protein: number; carbs: number; fat: number };
  confidence: number;
  assistantSummary: string;
  needsClarification: boolean;
  photoPath?: string | null;
  imageURL?: string | null;
  foodCategory?: string | null;
  imageStatus?: string | null;
};

function resolveUserID(data: any): string {
  // OPEN LOCAL-AUTH MODE:
  // No Firebase Auth, Firebase callable auth, or App Check required.
  const localUID = typeof data?._localUserID === "string" && data._localUserID.length > 0
    ? data._localUserID
    : null;
  if (localUID) return localUID;

  const clientUID = typeof data?._clientAuthUID === "string" && data._clientAuthUID.length > 0
    ? data._clientAuthUID
    : null;
  if (clientUID) return clientUID;

  return "local-user";
}

function assertString(value: unknown, name: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`${name} is required.`);
  }
  return value.trim();
}

function clampNumber(value: unknown, fallback = 0): number {
  const n = typeof value === "number" && Number.isFinite(value) ? value : fallback;
  return Math.max(0, n);
}

function normalizeMeal(raw: any): MealAnalysis {
  const seenItemIDs = new Map<string, number>();
  const items: MealItem[] = Array.isArray(raw?.items) ? raw.items.map((item: any, index: number) => ({
    id: uniqueFoodItemID(item?.id, item?.name, index, seenItemIDs),
    name: typeof item?.name === "string" && item.name.length > 0 ? item.name : "Food item",
    estimatedGrams: typeof item?.estimatedGrams === "number" ? item.estimatedGrams : null,
    servingDescription: typeof item?.servingDescription === "string" ? item.servingDescription : null,
    calories: Math.round(clampNumber(item?.calories)),
    protein: typeof item?.protein === "number" ? clampNumber(item.protein) : null,
    carbs: typeof item?.carbs === "number" ? clampNumber(item.carbs) : null,
    fat: typeof item?.fat === "number" ? clampNumber(item.fat) : null,
    confidence: Math.min(1, Math.max(0, typeof item?.confidence === "number" ? item.confidence : 0.65))
  })) : [];

  const totalCalories = Math.round(
    typeof raw?.totalCalories === "number" ? clampNumber(raw.totalCalories) : items.reduce((sum, item) => sum + item.calories, 0)
  );

  const mealTypeValues: MealType[] = ["breakfast", "lunch", "dinner", "snack", "dessert", "drink", "unknown"];
  const mealType: MealType = mealTypeValues.includes(raw?.mealType) ? raw.mealType : "unknown";
  const title = typeof raw?.title === "string" && raw.title.length > 0 ? raw.title : "Meal";
  const inferredMealType = inferMealTypeFromText(title, mealType);

  return {
    title,
    mealType: inferredMealType,
    items: items.length > 0 ? items : [{
      id: randomUUID(),
      name: "Meal",
      estimatedGrams: null,
      servingDescription: null,
      calories: totalCalories,
      protein: null,
      carbs: null,
      fat: null,
      confidence: 0.45
    }],
    totalCalories,
    macros: {
      protein: clampNumber(raw?.macros?.protein),
      carbs: clampNumber(raw?.macros?.carbs),
      fat: clampNumber(raw?.macros?.fat)
    },
    confidence: Math.min(1, Math.max(0, typeof raw?.confidence === "number" ? raw.confidence : 0.65)),
    assistantSummary: typeof raw?.assistantSummary === "string" ? raw.assistantSummary : "Logged your meal.",
    needsClarification: Boolean(raw?.needsClarification),
    photoPath: typeof raw?.photoPath === "string" ? raw.photoPath : null,
    imageURL: typeof raw?.imageURL === "string" ? raw.imageURL : null,
    foodCategory: typeof raw?.foodCategory === "string" ? raw.foodCategory : null,
    imageStatus: typeof raw?.imageStatus === "string" ? raw.imageStatus : null
  };
}

function uniqueFoodItemID(rawID: unknown, rawName: unknown, index: number, seen: Map<string, number>): string {
  const candidate = typeof rawID === "string" && rawID.trim().length > 0
    ? rawID
    : (typeof rawName === "string" && rawName.trim().length > 0 ? rawName : `item-${index + 1}`);
  const base = safeSlug(candidate) || `item-${index + 1}`;
  const count = (seen.get(base) ?? 0) + 1;
  seen.set(base, count);
  return count === 1 ? base : `${base}-${count}`;
}

function inferMealTypeFromText(text: unknown, fallback: MealType): MealType {
  if (typeof text !== "string") return fallback;
  const lower = text.toLowerCase();
  if (/\bbreakfast\b|\bbrunch\b|morning meal/.test(lower)) return "breakfast";
  if (/\blunch\b|midday meal/.test(lower)) return "lunch";
  if (/\bdinner\b|\bsupper\b|evening meal/.test(lower)) return "dinner";
  if (/\bsnack\b|snacking/.test(lower)) return "snack";
  if (/\bdessert\b/.test(lower)) return "dessert";
  if (/\bdrink\b|\bbeverage\b|\bsoda\b|\bcoffee\b|\blatte\b|\bjuice\b|\bcoke\b/.test(lower) && fallback === "unknown") return "drink";
  return fallback;
}

async function recordBackendLog(uid: string, type: string) {
  try {
    await getFirestore().collection("users").doc(uid).collection("backendLogs").add({
      type,
      createdAt: FieldValue.serverTimestamp()
    });
  } catch (error) {
    console.warn("MealRecap backend log failed", error);
  }
}

async function fetchJson(url: string, init?: RequestInit): Promise<any> {
  const response = await fetch(url, init);
  if (!response.ok) throw new Error(`Request failed ${response.status}`);
  return response.json();
}

async function searchUSDA(query: string, usdaKey: string): Promise<NutritionHint[]> {
  if (!usdaKey || !query) return [];
  try {
    const params = new URLSearchParams({ api_key: usdaKey, query, pageSize: "4" });
    const json = await fetchJson(`https://api.nal.usda.gov/fdc/v1/foods/search?${params.toString()}`);
    const foods = Array.isArray(json.foods) ? json.foods : [];
    return foods.slice(0, 4).map((food: any) => {
      const nutrients = Array.isArray(food.foodNutrients) ? food.foodNutrients : [];
      const find = (name: string) => nutrients.find((n: any) => String(n.nutrientName || "").toLowerCase().includes(name))?.value ?? null;
      return {
        source: "usda" as const,
        name: food.description || query,
        caloriesPer100g: find("energy"),
        proteinPer100g: find("protein"),
        carbsPer100g: find("carbohydrate"),
        fatPer100g: find("total lipid")
      };
    });
  } catch (error) {
    console.warn("USDA lookup failed", error);
    return [];
  }
}

async function searchOpenFoodFacts(query: string): Promise<NutritionHint[]> {
  if (!query) return [];
  try {
    const params = new URLSearchParams({ search_terms: query, search_simple: "1", action: "process", json: "1", page_size: "4" });
    const json = await fetchJson(`https://world.openfoodfacts.org/cgi/search.pl?${params.toString()}`, {
      headers: { "User-Agent": "MealRecap/1.0 (production nutrition lookup)" }
    });
    const products = Array.isArray(json.products) ? json.products : [];
    return products.slice(0, 4).map((product: any) => {
      const nutriments = product.nutriments || {};
      return {
        source: "openfoodfacts" as const,
        name: product.product_name || query,
        caloriesPer100g: nutriments["energy-kcal_100g"] ?? null,
        proteinPer100g: nutriments.proteins_100g ?? null,
        carbsPer100g: nutriments.carbohydrates_100g ?? null,
        fatPer100g: nutriments.fat_100g ?? null
      };
    });
  } catch (error) {
    console.warn("Open Food Facts lookup failed", error);
    return [];
  }
}

async function gatherHints(text: string, usdaKey: string): Promise<NutritionHint[]> {
  const seed = text.split(/[,.\n]/).map((s) => s.trim()).filter(Boolean).slice(0, 4);
  const hintSets = await Promise.all(seed.map(async (query) => {
    const [usda, off] = await Promise.all([searchUSDA(query, usdaKey), searchOpenFoodFacts(query)]);
    return [...usda, ...off].slice(0, 4);
  }));
  return hintSets.flat().slice(0, 12);
}

function mealJsonSchema() {
  return {
    type: "object",
    additionalProperties: false,
    properties: {
      title: { type: "string" },
      mealType: { type: "string", enum: ["breakfast", "lunch", "dinner", "snack", "dessert", "drink", "unknown"] },
      foodCategory: { type: "string" },
      items: {
        type: "array",
        minItems: 1,
        items: {
          type: "object",
          additionalProperties: false,
          properties: {
            id: { type: "string" },
            name: { type: "string" },
            estimatedGrams: { anyOf: [{ type: "number" }, { type: "null" }] },
            servingDescription: { anyOf: [{ type: "string" }, { type: "null" }] },
            calories: { type: "integer", minimum: 0 },
            protein: { anyOf: [{ type: "number" }, { type: "null" }] },
            carbs: { anyOf: [{ type: "number" }, { type: "null" }] },
            fat: { anyOf: [{ type: "number" }, { type: "null" }] },
            confidence: { type: "number", minimum: 0, maximum: 1 }
          },
          required: ["id", "name", "estimatedGrams", "servingDescription", "calories", "protein", "carbs", "fat", "confidence"]
        }
      },
      totalCalories: { type: "integer", minimum: 0 },
      macros: {
        type: "object",
        additionalProperties: false,
        properties: {
          protein: { type: "number", minimum: 0 },
          carbs: { type: "number", minimum: 0 },
          fat: { type: "number", minimum: 0 }
        },
        required: ["protein", "carbs", "fat"]
      },
      confidence: { type: "number", minimum: 0, maximum: 1 },
      assistantSummary: { type: "string" },
      needsClarification: { type: "boolean" }
    },
    required: ["title", "mealType", "foodCategory", "items", "totalCalories", "macros", "confidence", "assistantSummary", "needsClarification"]
  };
}

async function callOpenAI(input: any, schema: any, schemaName: string, apiKey: string): Promise<any> {
  if (!apiKey) throw new Error("OpenAI key is not configured.");

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: "gpt-4.1-mini",
      input,
      text: {
        format: {
          type: "json_schema",
          name: schemaName,
          schema,
          strict: true
        }
      }
    })
  });

  if (!response.ok) {
    const body = await response.text();
    console.error("OpenAI request failed", response.status, body.slice(0, 500));
    throw new Error("Meal analysis failed.");
  }

  const json: any = await response.json();
  const outputText = json.output_text || json.output?.flatMap((item: any) => item.content || []).find((content: any) => content.type === "output_text")?.text;
  if (typeof outputText !== "string") throw new Error("Meal analysis returned no structured text.");
  return JSON.parse(outputText);
}

const baseInstructions = `You are MealRecap's nutrition parser. Return only valid JSON matching the requested schema. Estimate calories honestly and label uncertainty through confidence. Do not claim food was weighed from a photo. Use estimatedGrams only when visually or textually reasonable. Prefer common serving sizes when grams are unknown. Keep assistantSummary short, warm, and direct.`;

const mealImageStyle = `Create a photorealistic, high-end editorial food image for MealRecap.
Style: warm off-white studio surface, real food only, soft natural window light, realistic shadows, ceramic plate or glassware when appropriate, tasteful overhead or slight 45-degree angle, no text, no logos, no packaging, no hands, no watermark, no utensils unless essential, minimal Apple-like composition, appetizing but honest.
The image should feel like a premium food journal asset shot by a professional food photographer, not a cartoon, not an illustration, not a stock-photo collage.`;

function safeSlug(input: string): string {
  return input.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 72) || "meal";
}

function canonicalMealDescriptor(meal: MealAnalysis): string {
  const itemNames = meal.items
    .map((item) => `${item.name} ${item.servingDescription ?? ""}`.trim().toLowerCase())
    .filter(Boolean)
    .sort()
    .join(" | ");
  return `${meal.title.toLowerCase()} :: ${meal.mealType} :: ${itemNames}`.replace(/\s+/g, " ").trim();
}

function mealImageCacheKey(meal: MealAnalysis, reference?: { mimeType: string; base64: string }): string {
  const referenceHash = reference ? createHash("sha256").update(reference.base64.slice(0, 120000)).digest("hex").slice(0, 12) : "no-reference";
  return createHash("sha256").update(`${canonicalMealDescriptor(meal)}::${referenceHash}`).digest("hex").slice(0, 28);
}

function imagePromptForMeal(meal: MealAnalysis, reference?: { mimeType: string; base64: string }): string {
  const items = meal.items.map((item) => {
    const serving = item.servingDescription ? ` (${item.servingDescription})` : "";
    return `${item.name}${serving}`;
  }).join(", ");
  const referenceInstruction = reference
    ? "Use the attached user meal photo as the factual source. Preserve the actual foods, portions, plating logic, and visible ingredients, but improve lighting, composition, color, and background into a clean MealRecap studio image."
    : "Create the meal as a realistic single cohesive food scene based only on the listed food items.";

  return `${mealImageStyle}\n${referenceInstruction}\nMeal title: ${meal.title}\nMeal type: ${meal.mealType}\nFood items: ${items}\nApproximate calories: ${meal.totalCalories}.\nComposition: square crop, generous negative space, hero food centered slightly above middle, realistic texture, crisp but soft, premium minimal nutrition journal aesthetic. Output should look like a real photo clipped into an iOS food journal, not an icon.`;
}

function extractGeminiInlineImage(json: any): { mimeType: string; data: string } | null {
  const parts = json?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return null;
  for (const part of parts) {
    const inline = part?.inlineData || part?.inline_data;
    if (inline?.data) {
      return {
        mimeType: inline.mimeType || inline.mime_type || "image/png",
        data: inline.data
      };
    }
  }
  return null;
}

async function callGeminiImage(promptParts: any[], apiKey: string, ctx?: RequestLog): Promise<{ mimeType: string; data: string; model: string; apiVersion: string } | null> {
  if (!apiKey) {
    if (ctx) logStep(ctx, "gemini.missingSecret"); else console.warn("GEMINI_API_KEY is not configured; skipping generated meal image.");
    return null;
  }

  // v24: Official Google GenAI SDK only. No manual REST payloads and no generationConfig.responseModalities.
  // Google's current JavaScript image-generation sample uses:
  //   ai.models.generateContent({ model: "gemini-3.1-flash-image", contents: prompt })
  // and reads candidates[0].content.parts[].inlineData.
  const models = [
    "gemini-3.1-flash-image",
    "gemini-2.5-flash-image",
    "gemini-3-pro-image"
  ];

  const promptText = promptParts
    .map((part) => typeof part?.text === "string" ? part.text : "")
    .filter(Boolean)
    .join("\n")
    .trim();

  const referencePart = promptParts.find((part) => part?.inlineData?.data);
  const ai = new GoogleGenAI({ apiKey });

  for (const model of models) {
    try {
      if (ctx) logStep(ctx, "gemini.sdk.request", { model, hasReference: Boolean(referencePart), promptChars: promptText.length });

      const contents: any = referencePart
        ? [{ role: "user", parts: [{ text: promptText }, referencePart] }]
        : promptText;

      const response: any = await ai.models.generateContent({ model, contents });
      const parts = response?.candidates?.[0]?.content?.parts ?? response?.parts ?? [];

      if (ctx) {
        logStep(ctx, "gemini.sdk.response", {
          model,
          candidates: Array.isArray(response?.candidates) ? response.candidates.length : 0,
          partsCount: Array.isArray(parts) ? parts.length : 0,
          responseKeys: response && typeof response === "object" ? Object.keys(response).slice(0, 12) : []
        });
      }

      const textPart = Array.isArray(parts) ? parts.find((part: any) => typeof part?.text === "string")?.text : undefined;
      if (ctx && textPart) logStep(ctx, "gemini.sdk.text", { model, text: String(textPart).slice(0, 300) });

      if (Array.isArray(parts)) {
        for (const part of parts) {
          const inline = part?.inlineData || part?.inline_data;
          if (inline?.data) {
            const mimeType = inline.mimeType || inline.mime_type || "image/png";
            if (ctx) logStep(ctx, "gemini.sdk.imageReceived", { model, mimeType, base64Chars: inline.data.length });
            return { mimeType, data: inline.data, model, apiVersion: "google-genai-sdk" };
          }
        }
      }

      if (ctx) logStep(ctx, "gemini.sdk.noInlineImage", { model, partsCount: Array.isArray(parts) ? parts.length : 0 });
    } catch (error: any) {
      if (ctx) {
        logError(ctx, "gemini.sdk.failed", error, {
          model,
          name: error?.name,
          status: error?.status,
          code: error?.code,
          cause: error?.cause ? String(error.cause).slice(0, 500) : undefined,
          raw: typeof error?.message === "string" ? error.message.slice(0, 1200) : undefined
        });
      } else {
        console.warn("Gemini SDK image generation failed", { model, error });
      }
    }
  }

  return null;
}

async function ensureFirebaseDownloadURL(path: string, ctx?: RequestLog): Promise<string | null> {
  try {
    const bucket = defaultBucket();
    const file = bucket.file(path);
    const [exists] = await file.exists();
    if (!exists) {
      if (ctx) logStep(ctx, "storage.downloadURL.missingFile", { path, bucket: bucket.name });
      return null;
    }

    const [metadata] = await file.getMetadata();
    const customMetadata = metadata.metadata && typeof metadata.metadata === "object"
      ? metadata.metadata as Record<string, string>
      : {};
    const existingTokens = typeof customMetadata.firebaseStorageDownloadTokens === "string"
      ? customMetadata.firebaseStorageDownloadTokens
      : "";
    let token = existingTokens.split(",").map((part) => part.trim()).filter(Boolean)[0];

    if (!token) {
      token = randomUUID();
      await file.setMetadata({
        metadata: {
          ...customMetadata,
          firebaseStorageDownloadTokens: token
        }
      });
      if (ctx) logStep(ctx, "storage.downloadURL.tokenAdded", { path, bucket: bucket.name });
    }

    return firebaseMediaURL(bucket.name, path, token);
  } catch (error) {
    if (ctx) logError(ctx, "storage.downloadURL.failed", error, { path });
    return null;
  }
}

async function getCachedGeneratedImage(cacheKey: string, ctx?: RequestLog): Promise<{ photoPath: string; imageURL?: string | null } | null> {
  try {
    const snap = await getFirestore().collection("foodImageCache").doc(cacheKey).get();
    const data = snap.data();
    const photoPath = data?.photoPath;
    if (typeof photoPath === "string" && photoPath.length > 0) {
      const cachedURL = typeof data?.imageURL === "string" ? data.imageURL : null;
      const tokenURL = await ensureFirebaseDownloadURL(photoPath, ctx);
      await snap.ref.set({
        lastUsedAt: FieldValue.serverTimestamp(),
        hits: FieldValue.increment(1),
        ...(tokenURL && tokenURL !== cachedURL ? { imageURL: tokenURL } : {})
      }, { merge: true });
      return {
        photoPath,
        imageURL: tokenURL ?? cachedURL
      };
    }
  } catch (error) {
    console.warn("Meal image cache read failed", error);
  }
  return null;
}

async function saveGeneratedImage(cacheKey: string, meal: MealAnalysis, image: { mimeType: string; data: string; model?: string; apiVersion?: string }, prompt: string, ctx?: RequestLog): Promise<{ photoPath: string; imageURL: string }> {
  const extension = image.mimeType.includes("jpeg") || image.mimeType.includes("jpg") ? "jpg" : "png";
  const path = `generatedFoodImages/${cacheKey}-${safeSlug(meal.title)}.${extension}`;
  const downloadToken = randomUUID();

  if (ctx) logStep(ctx, "storage.persist.enter", {
    path,
    configuredBucket: storageBucketName,
    mimeType: image.mimeType,
    base64Chars: typeof image.data === "string" ? image.data.length : 0
  });

  let buffer: Buffer;
  try {
    buffer = Buffer.from(image.data, "base64");
    if (!buffer.length) throw new Error("Generated image buffer is empty.");
    if (ctx) logStep(ctx, "storage.buffer.ready", { path, bytes: buffer.length, mimeType: image.mimeType });
  } catch (error) {
    if (ctx) logError(ctx, "storage.buffer.failed", error, { path, base64Chars: typeof image.data === "string" ? image.data.length : 0 });
    throw error;
  }

  const bucket = defaultBucket();
  if (ctx) logStep(ctx, "storage.bucket.ready", { bucket: bucket.name, configuredBucket: storageBucketName });

  const file = bucket.file(path);
  if (ctx) logStep(ctx, "storage.file.ready", { path, bucket: bucket.name });

  try {
    if (ctx) logStep(ctx, "storage.save.start", { path, bucket: bucket.name, bytes: buffer.length, mimeType: image.mimeType });
    await file.save(buffer, {
      resumable: false,
      validation: false,
      metadata: {
        contentType: image.mimeType,
        cacheControl: "public,max-age=31536000,immutable",
        metadata: {
          mealTitle: meal.title,
          cacheKey,
          generatedBy: "MealRecap",
          model: image.model ?? "unknown",
          firebaseStorageDownloadTokens: downloadToken
        }
      }
    });
    if (ctx) logStep(ctx, "storage.save.done", { path, bucket: bucket.name, bytes: buffer.length });
  } catch (error) {
    if (ctx) logError(ctx, "storage.save.failed", error, { path, bucket: bucket.name, bytes: buffer.length });
    throw error;
  }

  // Do NOT use file.makePublic(). New Firebase buckets often use uniform bucket-level access.\
  // The app uses the Firebase Storage SDK with photoPath, and this URL is only cached for diagnostics/fallback.
  const mediaURL = firebaseMediaURL(bucket.name, path, downloadToken);
  if (ctx) logStep(ctx, "storage.mediaURL.ready", { path, bucket: bucket.name, mediaURLPreview: mediaURL.slice(0, 180) });

  try {
    if (ctx) logStep(ctx, "imageCache.write.start", { cacheKey, path });
    await getFirestore().collection("foodImageCache").doc(cacheKey).set({
      photoPath: path,
      imageURL: mediaURL,
      title: meal.title,
      descriptor: canonicalMealDescriptor(meal),
      prompt,
      mimeType: image.mimeType,
      createdAt: FieldValue.serverTimestamp(),
      lastUsedAt: FieldValue.serverTimestamp(),
      hits: FieldValue.increment(1),
      model: image.model ?? "unknown",
      apiVersion: image.apiVersion ?? "unknown"
    }, { merge: true });
    if (ctx) logStep(ctx, "imageCache.write.done", { cacheKey, path });
  } catch (error) {
    if (ctx) logError(ctx, "imageCache.write.failed", error, { cacheKey, path });
    throw error;
  }

  if (ctx) logStep(ctx, "image.persist.done", { photoPath: path, bucket: bucket.name });
  return { photoPath: path, imageURL: mediaURL };
}

async function attachGeneratedMealImage(uid: string, date: string, meal: MealAnalysis, apiKey: string, reference?: { mimeType: string; base64: string }, ctx?: RequestLog): Promise<MealAnalysis> {
  try {
    const cacheKey = mealImageCacheKey(meal, reference);
    if (ctx) logStep(ctx, "image.cache.lookup", { cacheKey, title: meal.title, hasReference: Boolean(reference) });
    const cachedImage = await getCachedGeneratedImage(cacheKey, ctx);
    if (cachedImage) {
      if (ctx) logStep(ctx, "image.cache.hit", { cacheKey, photoPath: cachedImage.photoPath, hasImageURL: Boolean(cachedImage.imageURL) });
      return { ...meal, photoPath: cachedImage.photoPath, imageURL: cachedImage.imageURL, imageStatus: "ready" } as MealAnalysis & { imageURL?: string | null };
    }
    if (ctx) logStep(ctx, "image.cache.miss", { cacheKey });

    const prompt = imagePromptForMeal(meal, reference);
    const parts: any[] = [{ text: prompt }];
    if (reference) {
      parts.push({
        inlineData: {
          mimeType: reference.mimeType,
          data: reference.base64
        }
      });
    }

    if (ctx) logStep(ctx, "image.prompt", { prompt: prompt.slice(0, 500) });
    const generated = await callGeminiImage(parts, apiKey, ctx);
    if (!generated) {
      if (ctx) logStep(ctx, "image.failed.noGeneratedImage");
      return { ...meal, imageStatus: "failed" };
    }
    if (ctx) logStep(ctx, "image.calling.saveGeneratedImage", { cacheKey, title: meal.title, mimeType: generated.mimeType, base64Chars: generated.data.length });
    const savedImage = await saveGeneratedImage(cacheKey, meal, generated, prompt, ctx);
    await recordBackendLog(uid, `mealImageGenerated:${date}`);
    if (ctx) logStep(ctx, "image.done", { photoPath: savedImage.photoPath, hasImageURL: Boolean(savedImage.imageURL) });
    return { ...meal, photoPath: savedImage.photoPath, imageURL: savedImage.imageURL, imageStatus: "ready" } as MealAnalysis & { imageURL?: string | null };
  } catch (error) {
    if (ctx) logError(ctx, "image.exception", error, { title: meal.title }); else console.warn("Meal image generation skipped", error);
    return { ...meal, imageStatus: "failed" };
  }
}



async function referenceImageFromStoragePath(photoPath: unknown): Promise<{ mimeType: string; base64: string } | undefined> {
  if (typeof photoPath !== "string" || photoPath.length === 0) return undefined;
  if (!photoPath.includes("/mealPhotos/")) return undefined;
  try {
    const file = defaultBucket().file(photoPath);
    const [exists] = await file.exists();
    if (!exists) return undefined;
    const [metadata] = await file.getMetadata();
    const [buffer] = await file.download();
    return {
      mimeType: metadata.contentType || "image/jpeg",
      base64: buffer.toString("base64")
    };
  } catch (error) {
    console.warn("Reference meal photo could not be loaded", error);
    return undefined;
  }
}

function mealFromFirestore(data: any): MealAnalysis {
  const itemsRaw = Array.isArray(data.items) ? data.items : [];
  const seenItemIDs = new Map<string, number>();
  const items = itemsRaw.map((item: any, index: number) => ({
    id: uniqueFoodItemID(item?.id, item?.name, index, seenItemIDs),
    name: typeof item?.name === "string" && item.name.length > 0 ? item.name : "Food item",
    estimatedGrams: typeof item?.estimatedGrams === "number" ? item.estimatedGrams : null,
    servingDescription: typeof item?.servingDescription === "string" ? item.servingDescription : null,
    calories: Math.round(clampNumber(item?.calories)),
    protein: typeof item?.protein === "number" ? clampNumber(item.protein) : null,
    carbs: typeof item?.carbs === "number" ? clampNumber(item.carbs) : null,
    fat: typeof item?.fat === "number" ? clampNumber(item.fat) : null,
    confidence: Math.min(1, Math.max(0, typeof item?.confidence === "number" ? item.confidence : 0.65))
  }));

  const macros = data.macros || {};
  return normalizeMeal({
    title: typeof data.title === "string" ? data.title : "Meal",
    mealType: typeof data.mealType === "string" ? data.mealType : "unknown",
    items,
    totalCalories: typeof data.calories === "number" ? data.calories : items.reduce((sum: number, item: MealItem) => sum + item.calories, 0),
    macros: {
      protein: typeof macros.protein === "number" ? macros.protein : 0,
      carbs: typeof macros.carbs === "number" ? macros.carbs : 0,
      fat: typeof macros.fat === "number" ? macros.fat : 0
    },
    confidence: typeof data.confidence === "number" ? data.confidence : 0.65,
    assistantSummary: typeof data.assistantNote === "string" ? data.assistantNote : "Logged.",
    needsClarification: false,
    photoPath: typeof data.photoPath === "string" ? data.photoPath : null,
    imageURL: typeof data.imageURL === "string" ? data.imageURL : null,
    foodCategory: typeof data.foodCategory === "string" ? data.foodCategory : null,
    imageStatus: typeof data.imageStatus === "string" ? data.imageStatus : null
  });
}


function extractData(req: any): any {
  const body = req.body ?? {};
  return typeof body.data === "object" && body.data !== null ? body.data : body;
}

function sendCors(res: any) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

function httpHandler(endpoint: string, handler: (data: any, ctx: RequestLog) => Promise<any>) {
  return async (req: any, res: any) => {
    const ctx: RequestLog = { id: requestID(), endpoint, startedAt: Date.now() };
    sendCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: { message: "Use POST.", requestId: ctx.id } });
      return;
    }

    try {
      const data = extractData(req);
      logStep(ctx, "request.start", {
        hasData: Boolean(data),
        keys: data && typeof data === "object" ? Object.keys(data).slice(0, 20) : []
      });
      const result = await handler(data, ctx);
      logStep(ctx, "request.success");
      res.status(200).json({ result: { ...(typeof result === "object" && result !== null ? result : { value: result }), requestId: ctx.id } });
    } catch (error: any) {
      logError(ctx, "request.failed", error);
      res.status(200).json({
        error: {
          message: error?.message ?? "MealRecap backend failed.",
          code: "backend-error",
          requestId: ctx.id
        }
      });
    }
  };
}

const publicOptions256 = { region, timeoutSeconds: 30, memory: "256MiB" as const, invoker: "public" as const };
const publicOptions1G = { region, timeoutSeconds: 240, memory: "1GiB" as const, invoker: "public" as const };
const publicOptionsLong = { region, timeoutSeconds: 540, memory: "1GiB" as const, invoker: "public" as const };


async function pingHandler(data: any, ctx: RequestLog) {
  logStep(ctx, "ping.ok", { uid: resolveUserID(data) });
  return {
    ok: true,
    at: new Date().toISOString(),
    runtime: "nodejs20",
    authMode: "public-http-local-user",
    resolvedUID: resolveUserID(data)
  };
}

async function generateMealImageHandler(data: any, ctx: RequestLog) {
  const uid = assertString(data?.uid || resolveUserID(data), "uid");
  const date = assertString(data?.date, "date");
  const meal = normalizeMeal({
    title: data?.title || "Meal",
    mealType: data?.mealType || "unknown",
    foodCategory: data?.foodCategory || data?.mealType || "Food",
    items: Array.isArray(data?.items) ? data.items : [{ name: data?.title || "Meal", calories: Number(data?.totalCalories || 0) }],
    totalCalories: Number(data?.totalCalories || data?.calories || 0),
    macros: data?.macros || { protein: 0, carbs: 0, fat: 0 },
    confidence: 0.7,
    assistantSummary: "Generated a meal image.",
    needsClarification: false
  });
  logStep(ctx, "generateMealImage.start", { uid, date, title: meal.title, itemCount: meal.items.length });
  const reference = await referenceImageFromStoragePath(data?.photoPath || data?.storagePath);
  const withImage = await attachGeneratedMealImage(uid, date, meal, GEMINI_API_KEY.value(), reference, ctx);
  await recordBackendLog(uid, "generateMealImage");
  return {
    ok: Boolean(withImage.photoPath || (withImage as any).imageURL),
    photoPath: withImage.photoPath ?? null,
    imageURL: typeof (withImage as any).imageURL === "string" ? (withImage as any).imageURL : null,
    imageStatus: withImage.imageStatus ?? "failed"
  };
}

async function backfillMealImagesHandler(data: any, ctx: RequestLog) {
  const uid = assertString(data?.uid || resolveUserID(data), "uid");
  const date = assertString(data?.date, "date");
  const db = getFirestore();
  const mealsRef = db.collection("users").doc(uid).collection("days").doc(date).collection("meals");
  const snapshot = await mealsRef.get();

  let scanned = 0;
  let generated = 0;
  let skippedCached = 0;
  let failed = 0;
  const updated: string[] = [];
  const failures: { mealId: string; title: string; reason: string }[] = [];
  logStep(ctx, "backfill.start", { uid, date, count: snapshot.docs.length });

  for (const doc of snapshot.docs) {
    scanned += 1;
    const docData = doc.data();
    const existingPhotoPath = docData.photoPath;
    if (typeof existingPhotoPath === "string" && existingPhotoPath.startsWith("generatedFoodImages/")) {
      skippedCached += 1;
      logStep(ctx, "backfill.skip.hasGenerated", { mealId: doc.id, photoPath: existingPhotoPath });
      continue;
    }

    const meal = mealFromFirestore(docData);
    logStep(ctx, "backfill.meal", { mealId: doc.id, title: meal.title, existingPhotoPath });
    const reference = await referenceImageFromStoragePath(existingPhotoPath);
    const withImage = await attachGeneratedMealImage(uid, date, meal, GEMINI_API_KEY.value(), reference, ctx);
    if (withImage.photoPath && withImage.photoPath !== existingPhotoPath) {
      const updateData: Record<string, unknown> = {
        photoPath: withImage.photoPath,
        imageStatus: "ready",
        generatedPhotoUpdatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      };
      if (typeof withImage.imageURL === "string" && withImage.imageURL.length > 0) {
        updateData.imageURL = withImage.imageURL;
      }
      await doc.ref.set(updateData, { merge: true });
      generated += 1;
      updated.push(doc.id);
      logStep(ctx, "backfill.updated", { mealId: doc.id, photoPath: withImage.photoPath });
    } else {
      failed += 1;
      failures.push({ mealId: doc.id, title: meal.title, reason: withImage.imageStatus ?? "no-photoPath" });
      await doc.ref.set({ imageStatus: "failed", updatedAt: FieldValue.serverTimestamp() }, { merge: true });
      logStep(ctx, "backfill.failed", { mealId: doc.id, status: withImage.imageStatus });
    }
  }

  await recordBackendLog(uid, "backfillMealImages");
  return { ok: true, scanned, generated, skippedCached, failed, updated, failures };
}

async function analyzeMealTextHandler(data: any, ctx: RequestLog) {
  const uid = resolveUserID(data);
  const text = assertString(data?.text, "text");
  const date = assertString(data?.date, "date");
  logStep(ctx, "analysis.text.start", { uid, date, textPreview: text.slice(0, 160) });
  const hints = await gatherHints(text, USDA_API_KEY.value());
  logStep(ctx, "analysis.hints.done", { hintCount: hints.length });
  const raw = await callOpenAI([
    { role: "system", content: baseInstructions },
    { role: "user", content: JSON.stringify({ task: "analyze_one_meal_or_food_log", date, text, nutritionHints: hints }) }
  ], mealJsonSchema(), "meal_analysis", OPENAI_API_KEY.value());
  let result = normalizeMeal(raw);
  result.mealType = inferMealTypeFromText(`${text}\n${result.title}`, result.mealType);
  logStep(ctx, "analysis.openai.done", { title: result.title, calories: result.totalCalories, mealType: result.mealType });
  result = await attachGeneratedMealImage(uid, date, result, GEMINI_API_KEY.value(), undefined, ctx);
  await recordBackendLog(uid, "analyzeMealText");
  logStep(ctx, "analysis.text.done", { title: result.title, photoPath: result.photoPath ?? null, imageStatus: result.imageStatus ?? null });
  return result;
}

async function analyzeDayRecapHandler(data: any, ctx: RequestLog) {
  const uid = resolveUserID(data);
  const text = assertString(data?.text, "text");
  const date = assertString(data?.date, "date");
  logStep(ctx, "recap.start", { uid, date, textPreview: text.slice(0, 160) });
  const hints = await gatherHints(text, USDA_API_KEY.value());
  const schema = {
    type: "object",
    additionalProperties: false,
    properties: {
      meals: { type: "array", minItems: 1, items: mealJsonSchema() },
      assistantSummary: { type: "string" }
    },
    required: ["meals", "assistantSummary"]
  };
  const raw = await callOpenAI([
    { role: "system", content: baseInstructions },
    { role: "user", content: JSON.stringify({ task: "break_a_full_day_food_recap_into_meals", date, text, nutritionHints: hints }) }
  ], schema, "day_recap", OPENAI_API_KEY.value());
  await recordBackendLog(uid, "analyzeDayRecap");
  const normalizedMeals: MealAnalysis[] = Array.isArray(raw.meals) ? raw.meals.map((meal: any) => {
    const normalized = normalizeMeal(meal);
    normalized.mealType = inferMealTypeFromText(`${meal?.title ?? ""}\n${text}`, normalized.mealType);
    return normalized;
  }) : [];
  logStep(ctx, "recap.openai.done", { mealCount: normalizedMeals.length });
  const meals = await Promise.all(normalizedMeals.map((meal) => attachGeneratedMealImage(uid, date, meal, GEMINI_API_KEY.value(), undefined, ctx)));
  logStep(ctx, "recap.done", { mealCount: meals.length, photos: meals.filter((m) => Boolean(m.photoPath)).length });
  return {
    meals,
    assistantSummary: typeof raw.assistantSummary === "string" ? raw.assistantSummary : "Built your day recap."
  };
}

async function analyzeMealPhotoHandler(data: any, ctx: RequestLog) {
  const uid = resolveUserID(data);
  const storagePath = assertString(data?.storagePath, "storagePath");
  const date = assertString(data?.date, "date");
  logStep(ctx, "photo.start", { uid, date, storagePath });

  if (!storagePath.startsWith("users/") || !storagePath.includes("/mealPhotos/")) {
    throw new Error("Invalid MealRecap photo path.");
  }

  const file = defaultBucket().file(storagePath);
  const [exists] = await file.exists();
  if (!exists) throw new Error("Meal photo not found.");

  const [metadata] = await file.getMetadata();
  const contentType = metadata.contentType || "image/jpeg";
  const [buffer] = await file.download();
  const base64Image = buffer.toString("base64");
  logStep(ctx, "photo.loaded", { bytes: buffer.length, contentType });

  const raw = await callOpenAI([
    { role: "system", content: baseInstructions },
    {
      role: "user",
      content: [
        { type: "input_text", text: `Analyze this food photo for MealRecap on ${date}. Estimate portions, calories, and macros. Be honest about uncertainty.` },
        { type: "input_image", image_url: `data:${contentType};base64,${base64Image}`, detail: "auto" }
      ]
    }
  ], mealJsonSchema(), "meal_photo_analysis", OPENAI_API_KEY.value());

  let result = normalizeMeal(raw);
  logStep(ctx, "photo.openai.done", { title: result.title, calories: result.totalCalories });
  result = await attachGeneratedMealImage(uid, date, result, GEMINI_API_KEY.value(), { mimeType: contentType, base64: base64Image }, ctx);
  await recordBackendLog(uid, "analyzeMealPhoto");
  logStep(ctx, "photo.done", { title: result.title, photoPath: result.photoPath ?? null, imageStatus: result.imageStatus ?? null });
  return result;
}

// v24 public endpoints. These are the only active backend endpoints the iOS app should call.
// Legacy aliases were intentionally removed to reduce Cloud Run CPU usage and avoid stale function behavior.
export const mrv24Ping = onRequest(publicOptions256, httpHandler("mrv24Ping", pingHandler));
export const mrv24GenerateMealImage = onRequest({ ...publicOptions1G, secrets: [GEMINI_API_KEY] }, httpHandler("mrv24GenerateMealImage", generateMealImageHandler));
export const mrv24BackfillMealImages = onRequest({ ...publicOptionsLong, secrets: [GEMINI_API_KEY] }, httpHandler("mrv24BackfillMealImages", backfillMealImagesHandler));
export const mrv24AnalyzeMealText = onRequest({ ...publicOptions1G, secrets: [OPENAI_API_KEY, USDA_API_KEY, GEMINI_API_KEY], timeoutSeconds: 180 }, httpHandler("mrv24AnalyzeMealText", analyzeMealTextHandler));
export const mrv24AnalyzeDayRecap = onRequest({ ...publicOptions1G, secrets: [OPENAI_API_KEY, USDA_API_KEY, GEMINI_API_KEY], timeoutSeconds: 240 }, httpHandler("mrv24AnalyzeDayRecap", analyzeDayRecapHandler));
export const mrv24AnalyzeMealPhoto = onRequest({ ...publicOptions1G, secrets: [OPENAI_API_KEY, GEMINI_API_KEY], timeoutSeconds: 180 }, httpHandler("mrv24AnalyzeMealPhoto", analyzeMealPhotoHandler));
