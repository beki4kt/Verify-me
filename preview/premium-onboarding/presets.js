/* Presentation presets only. Production authorization remains server-owned. */
window.ChekmiPresets = Object.freeze({
  shop: Object.freeze({
    title: 'Shop & Retail', icon: 'shop', backendUseCase: 'shop',
    defaultReference: 'order', references: [['order', 'Order'], ['customer', 'Customer'], ['none', 'Payment ref']],
  }),
  food: Object.freeze({
    title: 'Food & Hospitality', icon: 'food', backendUseCase: 'restaurant',
    defaultReference: 'order', references: [['order', 'Order'], ['table', 'Table'], ['none', 'Payment ref']],
  }),
  service: Object.freeze({
    title: 'Services & Professionals', icon: 'service', backendUseCase: 'service',
    defaultReference: 'invoice', references: [['invoice', 'Invoice'], ['booking', 'Booking'], ['customer', 'Customer']],
  }),
  general: Object.freeze({
    title: 'General & Personal', icon: 'general', backendUseCase: 'general',
    defaultReference: 'none', references: [['none', 'Payment ref'], ['customer', 'Customer'], ['note', 'Note']],
  }),
  events: Object.freeze({
    title: 'Events & Venues', icon: 'events', backendUseCase: null, previewOnly: true,
    defaultReference: 'event', references: [['event', 'Event'], ['category', 'Category'], ['station', 'Station']],
    categories: ['Door Sales', 'Food & Drinks', 'Merchandise', 'Parking', 'VIP / Tables', 'Sponsorships', 'Other'],
  }),
});
