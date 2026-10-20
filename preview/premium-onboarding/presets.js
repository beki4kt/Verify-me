/* Presentation presets only. IDs stay stable; production authorization is server-owned. */
(() => {
  const choice = (id, label, reference, mode = 'solo', review = 'automatic', features = [], referenceLabel = null) =>
    Object.freeze({ id, label, reference, mode, review, features: Object.freeze(features), referenceLabel });
  const subtype = (title, question, choices, backendUseCase = null) =>
    Object.freeze({ title, question, choices: Object.freeze(choices), defaultWorkflow: choices[0].id, backendUseCase });
  const retailChoices = [
    choice('counter_sales', 'Counter Sales', 'none'),
    choice('orders_invoices', 'Orders / Invoices', 'invoice'),
    choice('both', 'Both', 'order', 'team'),
  ];
  const eventChoices = [
    choice('one_event', 'One Event', 'event'),
    choice('multiple_events', 'Multiple Events', 'event', 'team', 'automatic', ['events']),
  ];
  window.ChekmiPresets = Object.freeze({
    shop_retail: Object.freeze({
      title: 'Shop & Retail', icon: 'shop', backendUseCase: 'shop',
      references: [['order','Order'],['invoice','Invoice'],['customer','Customer'],['none','Payment ref']],
      subtypes: Object.freeze({
        supermarket: subtype('Grocery / Supermarket', 'Where do you receive payments?', [
          choice('single_counter','Single Counter','order'),
          choice('multiple_counters','Multiple Counters','order','team','automatic',['counter_labels','staff_attribution']),
        ]),
        clothing_fashion: subtype('Clothing & Fashion','How do customers pay?',retailChoices),
        electronics: subtype('Electronics','How do customers pay?',retailChoices),
        wholesale: subtype('Wholesale','How do customers pay?',[
          retailChoices[1],retailChoices[0],retailChoices[2],
        ]),
        online_store: subtype('Online Store','How do you process sales?',[
          choice('online_orders','Online Orders','order'),
          choice('mixed_sales','Mixed Sales','order','team'),
        ]),
        other_retail: subtype('Other Retail','How do customers pay?',retailChoices),
      }),
    }),
    food_hospitality: Object.freeze({
      title: 'Food & Hospitality', icon: 'food', backendUseCase: 'general',
      references: [['order','Order'],['table','Table'],['booking','Booking'],['invoice','Invoice'],['customer','Customer'],['none','Payment ref']],
      subtypes: Object.freeze({
        restaurant: subtype('Restaurant','How do you serve customers?',[
          choice('tables','Tables','table','team','review_required',['tables']),
          choice('counter','Counter','order'),
          choice('both','Both','order','team','review_required',['tables']),
        ],'restaurant'),
        cafe_fast_food: subtype('Café / Fast Food','How do you serve customers?',[
          choice('counter','Counter','order'),
          choice('tables','Tables','table','team','automatic',['tables']),
          choice('both','Both','order','team','automatic',['tables']),
        ],'restaurant'),
        hotel: subtype('Hotel','What do you match payments to?',[
          choice('bookings','Bookings','booking','team','review_required'),
          choice('front_desk','Front Desk','customer','team'),
        ]),
        bar_lounge: subtype('Bar / Lounge','How do you serve customers?',[
          choice('counter','Counter','order'),
          choice('tables','Tables','table','team','review_required',['tables']),
        ],'restaurant'),
        catering: subtype('Catering','What do you match payments to?',[
          choice('bookings','Bookings','booking'),
          choice('invoices','Invoices','invoice','team'),
        ]),
        other_hospitality: subtype('Other Hospitality','What do you match payments to?',[
          choice('orders','Orders','order'),
          choice('bookings','Bookings','booking'),
          choice('payment_reference','Payment Reference','none'),
        ]),
      }),
    }),
    services_professionals: Object.freeze({
      title: 'Services & Professionals', icon: 'service', backendUseCase: 'service',
      references: [['invoice','Invoice'],['booking','Booking'],['customer','Customer'],['note','Note'],['none','Payment ref']],
      subtypes: Object.freeze({
        salon: subtype('Salon / Beauty','How do you take payments?',[
          choice('bookings','Bookings','booking'),choice('walk_ins','Walk-ins','customer'),
        ]),
        repair_services: subtype('Repair Services','What do you match payments to?',[
          choice('jobs','Jobs','note','solo','automatic',[],'Job'),choice('invoices','Invoices','invoice'),
        ]),
        healthcare_services: subtype('Healthcare Services','What do you match payments to?',[
          choice('invoices','Invoices','invoice'),choice('bookings','Bookings','booking'),
        ]),
        freelance_agency: subtype('Freelance / Agency','What do you match payments to?',[
          choice('invoices','Invoices','invoice'),choice('projects','Projects','note','team','automatic',[],'Project'),
        ]),
        education_training: subtype('Education / Training','What do you match payments to?',[
          choice('invoices','Invoices','invoice'),choice('customers','Customers','customer'),
        ]),
        other_services: subtype('Other Services','What do you match payments to?',[
          choice('invoices','Invoices','invoice'),choice('bookings','Bookings','booking'),
          choice('payment_reference','Payment Reference','none'),
        ]),
      }),
    }),
    general_personal: Object.freeze({
      title: 'General & Personal', icon: 'general', backendUseCase: 'general',
      references: [['none','Payment ref'],['invoice','Invoice'],['order','Order'],['customer','Customer'],['note','Note']],
      subtypes: Object.freeze({
        general_business: subtype('General Business','How will you track payments?',[
          choice('payment_reference','Payment Reference','none'),choice('invoices','Invoices','invoice'),
        ]),
        solo_trader: subtype('Solo Trader','How will you track payments?',[
          choice('payment_reference','Payment Reference','none'),choice('orders','Orders','order'),
        ],'personal'),
        personal_payments: subtype('Personal Payments','How will you track payments?',[
          choice('payment_reference','Payment Reference','none'),choice('customers','People','customer','solo','automatic',[],'Person'),
        ],'personal'),
        other: subtype('Other','How will you track payments?',[
          choice('payment_reference','Payment Reference','none'),choice('notes','Notes','note'),
        ]),
      }),
    }),
    events_venues: Object.freeze({
      title: 'Events & Venues', icon: 'events', backendUseCase: null, previewOnly: true,
      references: [['event','Event'],['category','Category'],['station','Station'],['none','Payment ref']],
      categories: ['Door Sales','Food & Drinks','Merchandise','Parking','VIP / Tables','Sponsorships','Other'],
      subtypes: Object.freeze({
        concert_festival: subtype('Concert / Festival','Where do you collect payments?',[
          choice('one_station','One Station','event'),
          choice('multiple_stations','Multiple Stations','station','team','review_required',['events','stations']),
        ]),
        conference_exhibition: subtype('Conference / Exhibition','What payments do you track?',[
          choice('onsite_sales','On-site Sales','event'),
          choice('vendors_sponsors','Vendors & Sponsors','category','team','review_required',['events','categories']),
        ]),
        private_event: subtype('Private Event','Where do you collect payments?',[
          choice('one_station','One Station','event'),
          choice('multiple_stations','Multiple Stations','station','team','automatic',['events','stations']),
        ]),
        event_venue: subtype('Event Venue','How do you organize payments?',eventChoices),
        other_events: subtype('Other Events','How do you organize payments?',eventChoices),
      }),
    }),
  });
})();
