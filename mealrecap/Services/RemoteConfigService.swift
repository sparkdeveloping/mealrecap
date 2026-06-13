import Foundation
import FirebaseRemoteConfig

@MainActor
final class RemoteConfigService: ObservableObject {
    @Published private(set) var limits = SmartActionLimits()
    @Published private(set) var paywallEnabled = true

    private let remoteConfig = RemoteConfig.remoteConfig()

    func configureAndFetch() async {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults([
            "smart_actions_new_user_limit": 12 as NSObject,
            "smart_actions_new_user_days": 7 as NSObject,
            "smart_actions_weekly_free_limit": 6 as NSObject,
            "smart_action_cost_text": 1 as NSObject,
            "smart_action_cost_voice": 1 as NSObject,
            "smart_action_cost_photo": 3 as NSObject,
            "smart_action_cost_day_recap": 2 as NSObject,
            "paywall_enabled": true as NSObject
        ])
        do {
            try await remoteConfig.fetchAndActivate()
        } catch {
            // Use defaults. Do not block app startup.
        }
        limits = SmartActionLimits(
            onboardingLimit: remoteConfig["smart_actions_new_user_limit"].numberValue.intValue,
            onboardingDays: remoteConfig["smart_actions_new_user_days"].numberValue.intValue,
            weeklyLimit: remoteConfig["smart_actions_weekly_free_limit"].numberValue.intValue,
            textCost: remoteConfig["smart_action_cost_text"].numberValue.intValue,
            voiceCost: remoteConfig["smart_action_cost_voice"].numberValue.intValue,
            photoCost: remoteConfig["smart_action_cost_photo"].numberValue.intValue,
            dayRecapCost: remoteConfig["smart_action_cost_day_recap"].numberValue.intValue
        )
        paywallEnabled = remoteConfig["paywall_enabled"].boolValue
    }
}
