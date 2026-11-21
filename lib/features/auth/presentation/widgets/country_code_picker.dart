import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class Country {
  const Country(this.name, this.flag, this.dialCode);
  final String name;
  final String flag;
  final String dialCode;
}

const kCountries = <Country>[
  Country('Jordan', '🇯🇴', '+962'),
  Country('Saudi Arabia', '🇸🇦', '+966'),
  Country('United Arab Emirates', '🇦🇪', '+971'),
  Country('Palestine', '🇵🇸', '+970'),
  Country('Egypt', '🇪🇬', '+20'),
  Country('Iraq', '🇮🇶', '+964'),
  Country('Kuwait', '🇰🇼', '+965'),
  Country('Qatar', '🇶🇦', '+974'),
  Country('Bahrain', '🇧🇭', '+973'),
  Country('Oman', '🇴🇲', '+968'),
  Country('Lebanon', '🇱🇧', '+961'),
  Country('Syria', '🇸🇾', '+963'),
  Country('Morocco', '🇲🇦', '+212'),
  Country('Algeria', '🇩🇿', '+213'),
  Country('Tunisia', '🇹🇳', '+216'),
  Country('Libya', '🇱🇾', '+218'),
  Country('Yemen', '🇾🇪', '+967'),
  Country('Sudan', '🇸🇩', '+249'),
  Country('Türkiye', '🇹🇷', '+90'),
  Country('United States', '🇺🇸', '+1'),
  Country('Canada', '🇨🇦', '+1'),
  Country('United Kingdom', '🇬🇧', '+44'),
  Country('Germany', '🇩🇪', '+49'),
  Country('France', '🇫🇷', '+33'),
  Country('Italy', '🇮🇹', '+39'),
  Country('Spain', '🇪🇸', '+34'),
  Country('Netherlands', '🇳🇱', '+31'),
  Country('Sweden', '🇸🇪', '+46'),
  Country('India', '🇮🇳', '+91'),
  Country('Pakistan', '🇵🇰', '+92'),
  Country('Indonesia', '🇮🇩', '+62'),
  Country('Malaysia', '🇲🇾', '+60'),
  Country('Australia', '🇦🇺', '+61'),
  Country('Brazil', '🇧🇷', '+55'),
];

Future<Country?> showCountryPicker(BuildContext context) {
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _CountrySheet(),
  );
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet();
  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final items =
        kCountries
            .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()) || c.dialCode.contains(_query))
            .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(hintText: 'Search country', prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final c = items[i];
                return ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                  title: Text(c.name),
                  trailing: Text(c.dialCode, style: TextStyle(color: context.palette.textSecondary)),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
