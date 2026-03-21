import 'package:flutter/material.dart';

class FolderUiCatalog {
  const FolderUiCatalog._();

  static const colorKeys = <String>[
    'violet',
    'indigo',
    'blue',
    'cyan',
    'teal',
    'green',
    'lime',
    'amber',
    'orange',
    'red',
    'pink',
    'slate',
  ];

  static const iconKeys = <String>[
    'travel',
    'work',
    'health',
    'finance',
    'study',
    'home',
    'shopping',
    'media',
    'productivity',
    'tools',
    'food',
    'fitness',
    'family',
    'business',
    'notes',
    'favorites',
    'transport',
    'planning',
    'security',
    'communication',
    'documents',
    'entertainment',
    'utilities',
    'photos',
    'education',
    'medical',
    'lifestyle',
    'general',
  ];

  static IconData iconFor(String key) {
    switch (key) {
      case 'travel':
        return Icons.flight_takeoff_rounded;
      case 'work':
        return Icons.work_outline_rounded;
      case 'health':
        return Icons.favorite_outline_rounded;
      case 'finance':
        return Icons.account_balance_wallet_outlined;
      case 'study':
        return Icons.school_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'media':
        return Icons.movie_outlined;
      case 'tools':
        return Icons.build_outlined;
      case 'productivity':
        return Icons.task_alt_outlined;
      case 'favorites':
        return Icons.star_outline_rounded;
      case 'fitness':
        return Icons.fitness_center_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'family':
        return Icons.family_restroom_outlined;
      case 'business':
        return Icons.business_center_outlined;
      case 'security':
        return Icons.security_outlined;
      case 'notes':
        return Icons.sticky_note_2_outlined;
      case 'transport':
        return Icons.directions_car_outlined;
      case 'planning':
        return Icons.event_note_outlined;
      case 'communication':
        return Icons.chat_bubble_outline_rounded;
      case 'documents':
        return Icons.description_outlined;
      case 'entertainment':
        return Icons.celebration_outlined;
      case 'utilities':
        return Icons.extension_outlined;
      case 'photos':
        return Icons.photo_camera_outlined;
      case 'education':
        return Icons.cast_for_education_outlined;
      case 'medical':
        return Icons.medical_services_outlined;
      case 'lifestyle':
        return Icons.self_improvement_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  static Color colorFor(String key) {
    switch (key) {
      case 'violet':
        return const Color(0xFF7C3AED);
      case 'indigo':
        return const Color(0xFF4F46E5);
      case 'blue':
        return const Color(0xFF2563EB);
      case 'cyan':
        return const Color(0xFF0891B2);
      case 'teal':
        return const Color(0xFF0D9488);
      case 'green':
        return const Color(0xFF16A34A);
      case 'lime':
        return const Color(0xFF65A30D);
      case 'amber':
        return const Color(0xFFD97706);
      case 'orange':
        return const Color(0xFFEA580C);
      case 'red':
        return const Color(0xFFDC2626);
      case 'pink':
        return const Color(0xFFDB2777);
      case 'slate':
      default:
        return const Color(0xFF475569);
    }
  }
}
