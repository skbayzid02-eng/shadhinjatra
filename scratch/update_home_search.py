import os
import re

file_path = r'D:\laragon\www\shadhinjatra\APP_SHADHINJATRA_USER\shadhinjatra\lib\screens\home_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Increase Nominatim limit
content = content.replace('limit=5', 'limit=10')

# Replace _buildSearchField to add optionsViewBuilder
old_build_search = """  Widget _buildSearchField({required TextEditingController controller, required String hint, required IconData icon, required Color iconColor, required bool isDestination}) {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (TextEditingValue textEditingValue) => _searchLocation(textEditingValue.text),
      displayStringForOption: (option) => option['display_name'] ?? '',
      onSelected: (option) {
        setState(() {
          controller.text = option['display_name'];
          if (isDestination) {
            _dropoffLatLng = LatLng(double.parse(option['lat']), double.parse(option['lon']));
            _fetchRoute();
          } else {
            _pickupLatLng = LatLng(double.parse(option['lat']), double.parse(option['lon']));
          }
        });
      },
      fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
        if (controller.text != fieldController.text && !focusNode.hasFocus) {
          fieldController.text = controller.text;
        }
        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          style: const TextStyle(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
            prefixIcon: Icon(icon, color: iconColor, size: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: isDestination && _isRouting 
               ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)))
               : null
          ),
          onChanged: (val) => controller.text = val,
        );
      },
    );
  }"""

new_build_search = """  Widget _buildSearchField({required TextEditingController controller, required String hint, required IconData icon, required Color iconColor, required bool isDestination}) {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (TextEditingValue textEditingValue) => _searchLocation(textEditingValue.text),
      displayStringForOption: (option) => option['display_name'] ?? '',
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 250, maxWidth: MediaQuery.of(context).size.width - 40),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  final name = option['display_name'] ?? '';
                  final parts = name.split(',');
                  final shortName = parts.isNotEmpty ? parts[0] : name;
                  final subName = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                      child: const Icon(Icons.location_on, color: Colors.black54),
                    ),
                    title: Text(shortName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: subName.isNotEmpty ? Text(subName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)) : null,
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (option) {
        setState(() {
          controller.text = option['display_name'];
          if (isDestination) {
            _dropoffLatLng = LatLng(double.parse(option['lat']), double.parse(option['lon']));
            _fetchRoute();
          } else {
            _pickupLatLng = LatLng(double.parse(option['lat']), double.parse(option['lon']));
          }
        });
      },
      fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
        if (controller.text != fieldController.text && !focusNode.hasFocus) {
          fieldController.text = controller.text;
        }
        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          style: const TextStyle(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
            prefixIcon: Icon(icon, color: iconColor, size: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: isDestination && _isRouting 
               ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)))
               : null
          ),
          onChanged: (val) => controller.text = val,
        );
      },
    );
  }"""

content = content.replace(old_build_search, new_build_search)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated home_screen.dart")
