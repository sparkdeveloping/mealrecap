export function PhoneMockup() {
  return (
    <div className="phone-wrap" aria-hidden="true">
      <div className="phone">
        <div className="phone-screen">
          <div className="island" />
          <div className="phone-logo"><span>MEAL</span><br /><span>RECAP</span></div>
          <div className="phone-date">JUN 12</div>
          <div className="phone-title">Today</div>
          <div className="phone-cal"><strong>1,722</strong><span>of 2,200 cal</span></div>
          <div className="phone-bar" />
          <div className="phone-macros"><span>85 Protein</span><span>137 Carbs</span><span>77 Fat</span></div>
          <div className="phone-card">
            <div className="phone-chip">“ Lunch was 2 McDoubles and a Coke</div>
            <div className="phone-meal">
              <div className="phone-image">🍴</div>
              <div>
                <h4>Lunch with 2 McDoubles</h4>
                <p>fast food · 7:58 AM</p>
              </div>
              <strong>1,352</strong>
            </div>
          </div>
          <div className="phone-card">
            <div className="phone-chip">Rice and chicken</div>
            <div className="phone-meal">
              <div className="phone-image">✦</div>
              <div>
                <h4>Rice and Chicken</h4>
                <p>mixed dish · 8:23 AM</p>
              </div>
              <strong>370</strong>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
