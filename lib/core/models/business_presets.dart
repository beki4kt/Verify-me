import 'package:flutter/widgets.dart';

import '../theme/app_icons.dart';

/// Presentation defaults only. Workspace membership and capabilities remain
/// server-owned; a preset never grants a permission.
class WorkflowChoice {
  const WorkflowChoice(
    this.id,
    this.label,
    this.reference, {
    this.team = false,
    this.review = 'automatic',
  });

  final String id;
  final String label;
  final String reference;
  final bool team;
  final String review;
}

class BusinessSubtype {
  const BusinessSubtype(
    this.id,
    this.label,
    this.question,
    this.choices, {
    this.backendUseCase,
  });

  final String id;
  final String label;
  final String question;
  final List<WorkflowChoice> choices;
  final String? backendUseCase;
}

class BusinessCategory {
  const BusinessCategory(
    this.id,
    this.label,
    this.icon,
    this.backendUseCase,
    this.subtypes, {
    this.previewOnly = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final String backendUseCase;
  final List<BusinessSubtype> subtypes;
  final bool previewOnly;
}

abstract final class BusinessPresets {
  static const _retail = [
    WorkflowChoice('counter_sales', 'Counter Sales', 'none'),
    WorkflowChoice('orders_invoices', 'Orders / Invoices', 'invoice'),
    WorkflowChoice('both', 'Both', 'order', team: true),
  ];
  static const _event = [
    WorkflowChoice('one_event', 'One Event', 'note'),
    WorkflowChoice('multiple_events', 'Multiple Events', 'note', team: true),
  ];

  static const categories = <BusinessCategory>[
    BusinessCategory(
      'shop_retail',
      'Shop & Retail',
      AppIcons.storefront,
      'shop',
      [
        BusinessSubtype(
          'supermarket',
          'Grocery / Supermarket',
          'Where do you receive payments?',
          [
            WorkflowChoice('single_counter', 'Single Counter', 'order'),
            WorkflowChoice(
              'multiple_counters',
              'Multiple Counters',
              'order',
              team: true,
            ),
          ],
        ),
        BusinessSubtype(
          'clothing_fashion',
          'Clothing & Fashion',
          'How do customers pay?',
          _retail,
        ),
        BusinessSubtype(
          'electronics',
          'Electronics',
          'How do customers pay?',
          _retail,
        ),
        BusinessSubtype(
          'wholesale',
          'Wholesale',
          'How do customers pay?',
          _retail,
        ),
        BusinessSubtype(
          'online_store',
          'Online Store',
          'How do you process sales?',
          [
            WorkflowChoice('online_orders', 'Online Orders', 'order'),
            WorkflowChoice('mixed_sales', 'Mixed Sales', 'order', team: true),
          ],
        ),
        BusinessSubtype(
          'other_retail',
          'Other Retail',
          'How do customers pay?',
          _retail,
        ),
      ],
    ),
    BusinessCategory(
      'food_hospitality',
      'Food & Hospitality',
      AppIcons.serviceBell,
      'general',
      [
        BusinessSubtype(
          'restaurant',
          'Restaurant',
          'How do you serve customers?',
          [
            WorkflowChoice(
              'tables',
              'Tables',
              'table',
              team: true,
              review: 'review_required',
            ),
            WorkflowChoice('counter', 'Counter', 'order'),
            WorkflowChoice(
              'both',
              'Both',
              'order',
              team: true,
              review: 'review_required',
            ),
          ],
          backendUseCase: 'restaurant',
        ),
        BusinessSubtype(
          'cafe_fast_food',
          'Café / Fast Food',
          'How do you serve customers?',
          [
            WorkflowChoice('counter', 'Counter', 'order'),
            WorkflowChoice('tables', 'Tables', 'table', team: true),
            WorkflowChoice('both', 'Both', 'order', team: true),
          ],
          backendUseCase: 'restaurant',
        ),
        BusinessSubtype('hotel', 'Hotel', 'What do you match payments to?', [
          WorkflowChoice(
            'bookings',
            'Bookings',
            'booking',
            team: true,
            review: 'review_required',
          ),
          WorkflowChoice('front_desk', 'Front Desk', 'customer', team: true),
        ]),
        BusinessSubtype(
          'bar_lounge',
          'Bar / Lounge',
          'How do you serve customers?',
          [
            WorkflowChoice('counter', 'Counter', 'order'),
            WorkflowChoice(
              'tables',
              'Tables',
              'table',
              team: true,
              review: 'review_required',
            ),
          ],
          backendUseCase: 'restaurant',
        ),
        BusinessSubtype(
          'catering',
          'Catering',
          'What do you match payments to?',
          [
            WorkflowChoice('bookings', 'Bookings', 'booking'),
            WorkflowChoice('invoices', 'Invoices', 'invoice', team: true),
          ],
        ),
        BusinessSubtype(
          'other_hospitality',
          'Other Hospitality',
          'What do you match payments to?',
          [
            WorkflowChoice('orders', 'Orders', 'order'),
            WorkflowChoice('bookings', 'Bookings', 'booking'),
            WorkflowChoice('payment_reference', 'Payment Reference', 'none'),
          ],
        ),
      ],
    ),
    BusinessCategory(
      'services_professionals',
      'Services & Professionals',
      AppIcons.work,
      'service',
      [
        BusinessSubtype(
          'salon',
          'Salon / Beauty',
          'How do you take payments?',
          [
            WorkflowChoice('bookings', 'Bookings', 'booking'),
            WorkflowChoice('walk_ins', 'Walk-ins', 'customer'),
          ],
        ),
        BusinessSubtype(
          'repair_services',
          'Repair Services',
          'What do you match payments to?',
          [
            WorkflowChoice('jobs', 'Jobs', 'note'),
            WorkflowChoice('invoices', 'Invoices', 'invoice'),
          ],
        ),
        BusinessSubtype(
          'healthcare_services',
          'Healthcare Services',
          'What do you match payments to?',
          [
            WorkflowChoice('invoices', 'Invoices', 'invoice'),
            WorkflowChoice('bookings', 'Bookings', 'booking'),
          ],
        ),
        BusinessSubtype(
          'freelance_agency',
          'Freelance / Agency',
          'What do you match payments to?',
          [
            WorkflowChoice('invoices', 'Invoices', 'invoice'),
            WorkflowChoice('projects', 'Projects', 'note', team: true),
          ],
        ),
        BusinessSubtype(
          'education_training',
          'Education / Training',
          'What do you match payments to?',
          [
            WorkflowChoice('invoices', 'Invoices', 'invoice'),
            WorkflowChoice('customers', 'Customers', 'customer'),
          ],
        ),
        BusinessSubtype(
          'other_services',
          'Other Services',
          'What do you match payments to?',
          [
            WorkflowChoice('invoices', 'Invoices', 'invoice'),
            WorkflowChoice('bookings', 'Bookings', 'booking'),
            WorkflowChoice('payment_reference', 'Payment Reference', 'none'),
          ],
        ),
      ],
    ),
    BusinessCategory(
      'general_personal',
      'General & Personal',
      AppIcons.wallet,
      'general',
      [
        BusinessSubtype(
          'general_business',
          'General Business',
          'How will you track payments?',
          [
            WorkflowChoice('payment_reference', 'Payment Reference', 'none'),
            WorkflowChoice('invoices', 'Invoices', 'invoice'),
          ],
        ),
        BusinessSubtype(
          'solo_trader',
          'Solo Trader',
          'How will you track payments?',
          [
            WorkflowChoice('payment_reference', 'Payment Reference', 'none'),
            WorkflowChoice('orders', 'Orders', 'order'),
          ],
          backendUseCase: 'personal',
        ),
        BusinessSubtype(
          'personal_payments',
          'Personal Payments',
          'How will you track payments?',
          [
            WorkflowChoice('payment_reference', 'Payment Reference', 'none'),
            WorkflowChoice('customers', 'People', 'customer'),
          ],
          backendUseCase: 'personal',
        ),
        BusinessSubtype('other', 'Other', 'How will you track payments?', [
          WorkflowChoice('payment_reference', 'Payment Reference', 'none'),
          WorkflowChoice('notes', 'Notes', 'note'),
        ]),
      ],
    ),
    BusinessCategory(
      'events_venues',
      'Events & Venues',
      AppIcons.calendar,
      'general',
      [
        BusinessSubtype(
          'concert_festival',
          'Concert / Festival',
          'Where do you collect payments?',
          [
            WorkflowChoice('one_station', 'One Station', 'note'),
            WorkflowChoice(
              'multiple_stations',
              'Multiple Stations',
              'note',
              team: true,
              review: 'review_required',
            ),
          ],
        ),
        BusinessSubtype(
          'conference_exhibition',
          'Conference / Exhibition',
          'What payments do you track?',
          [
            WorkflowChoice('onsite_sales', 'On-site Sales', 'note'),
            WorkflowChoice(
              'vendors_sponsors',
              'Vendors & Sponsors',
              'note',
              team: true,
              review: 'review_required',
            ),
          ],
        ),
        BusinessSubtype(
          'private_event',
          'Private Event',
          'Where do you collect payments?',
          [
            WorkflowChoice('one_station', 'One Station', 'note'),
            WorkflowChoice(
              'multiple_stations',
              'Multiple Stations',
              'note',
              team: true,
            ),
          ],
        ),
        BusinessSubtype(
          'event_venue',
          'Event Venue',
          'How do you organize payments?',
          _event,
        ),
        BusinessSubtype(
          'other_events',
          'Other Events',
          'How do you organize payments?',
          _event,
        ),
      ],
      previewOnly: true,
    ),
  ];

  static BusinessCategory category(String id) => categories.firstWhere(
    (item) => item.id == id,
    orElse: () => categories[3],
  );

  static BusinessSubtype subtype(BusinessCategory category, String id) =>
      category.subtypes.firstWhere(
        (item) => item.id == id,
        orElse: () => category.subtypes.first,
      );

  static WorkflowChoice workflow(BusinessSubtype subtype, String id) => subtype
      .choices
      .firstWhere((item) => item.id == id, orElse: () => subtype.choices.first);
}
