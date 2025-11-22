# Dark Mode Audit - StudySwap App

## Summary
This document lists all screens in the app and their dark mode readiness status.

---

## ✅ ALREADY DARK MODE READY

### 1. **main.dart**
- Status: ✅ COMPLETE
- Theme configuration with light and dark themes defined
- Uses ThemeProvider for theme switching
- All colors properly configured for both modes

### 2. **main_screen.dart**
- Status: ✅ COMPLETE
- Bottom navigation uses theme-aware colors
- Background and shadows adapt to brightness
- Icons use theme colors

### 3. **chat_screen.dart**
- Status: ✅ COMPLETE (Just Updated)
- AppBar colors use theme
- Text colors use theme
- Input fields use theme-aware colors
- Media preview adapts to dark mode
- Message bubbles have proper contrast

### 4. **profile_screen.dart**
- Status: ✅ COMPLETE (Just Updated)
- Scaffold background uses theme
- AppBar uses theme colors
- Cards use cardColor from theme
- Text colors use theme
- Menu items adapt to dark mode

### 5. **browse_screen.dart**
- Status: ✅ MOSTLY COMPLETE
- Filter buttons use theme-aware colors
- Shadows adapt to brightness
- Some hardcoded greys but mostly theme-aware

---

## ⚠️ NEEDS DARK MODE UPDATES

### 1. **home_screen.dart**
- Status: ⚠️ PARTIAL
- Issues:
  - Hardcoded `Colors.grey[600]`, `Colors.grey[500]`, `Colors.grey[400]` for text
  - Hardcoded `Colors.grey[300]` for backgrounds
  - Some shadows use hardcoded colors
- Needs: Replace grey colors with theme-aware alternatives

### 2. **item_detail_screen.dart**
- Status: ⚠️ PARTIAL
- Issues:
  - Multiple hardcoded `Colors.grey[300]`, `Colors.grey[400]`, `Colors.grey[600]`
  - Card backgrounds hardcoded to `Colors.white`
  - Border colors hardcoded
  - Review section uses hardcoded greys
- Needs: Theme-aware colors for all grey shades and card backgrounds

### 3. **messages_screen.dart**
- Status: ⚠️ PARTIAL
- Issues:
  - AppBar has hardcoded `Colors.white` background
  - Some text colors hardcoded
  - Filter buttons need theme awareness
- Needs: AppBar and text color updates

### 4. **favorites_screen.dart**
- Status: ⚠️ PARTIAL
- Issues:
  - Scaffold background hardcoded to `Colors.grey[50]`
  - AppBar hardcoded to `Colors.white`
  - Card backgrounds hardcoded to `Colors.white`
  - Text colors use hardcoded greys
- Needs: Complete theme-aware color replacement

### 5. **reviews_screen.dart**
- Status: ⚠️ PARTIAL
- Issues:
  - Scaffold background hardcoded to `Colors.grey[50]`
  - AppBar hardcoded to `Colors.white`
  - Card backgrounds hardcoded to `Colors.white`
  - Text colors hardcoded
- Needs: Complete theme-aware color replacement

### 6. **transaction_history_screen.dart**
- Status: ⚠️ PARTIAL
- Issues:
  - Scaffold background hardcoded to `Colors.grey[50]`
  - AppBar hardcoded to `Colors.white`
  - Card backgrounds hardcoded to `Colors.white`
  - Text colors use hardcoded greys
- Needs: Complete theme-aware color replacement

### 7. **user_profile_screen.dart**
- Status: ⚠️ PARTIAL
- Issues:
  - Scaffold background hardcoded to `Colors.grey[50]`
  - AppBar hardcoded to `Colors.white`
  - Multiple card backgrounds hardcoded to `Colors.white`
  - Text colors hardcoded
  - Shadows use hardcoded colors
- Needs: Complete theme-aware color replacement

### 8. **user_search_screen.dart**
- Status: ⚠️ PARTIAL
- Issues:
  - Scaffold background hardcoded to `Colors.grey[50]`
  - AppBar hardcoded to `Colors.white`
  - TextField background hardcoded to `Colors.grey[100]`
  - Text colors hardcoded
- Needs: Theme-aware colors for all elements

### 9. **chatsupport.dart**
- Status: ⚠️ PARTIAL
- Issues:
  - Scaffold background hardcoded to `Colors.grey[50]`
  - AppBar hardcoded to `Colors.white`
  - Bubble colors hardcoded (`Colors.blue[400]`, `Colors.grey[200]`)
  - Text colors hardcoded
- Needs: Theme-aware bubble and background colors

### 10. **complete_profile_screen.dart**
- Status: ⚠️ PARTIAL
- Issues:
  - Card backgrounds hardcoded to `Colors.white`
  - Text colors hardcoded to `Colors.black87`, `Colors.grey[600]`
  - Input field backgrounds hardcoded
- Needs: Theme-aware colors for cards and text

### 11. **login.dart**
- Status: ⚠️ PARTIAL
- Issues:
  - Card backgrounds hardcoded to `Colors.white`
  - Text colors hardcoded to `Colors.black87`
  - Input field backgrounds hardcoded
  - Button colors hardcoded
- Needs: Theme-aware colors for all elements

### 12. **signup.dart**
- Status: ⚠️ PARTIAL
- Issues:
  - Card backgrounds hardcoded to `Colors.white`
  - Text colors hardcoded to `Colors.black87`
  - Input field backgrounds hardcoded
  - Button colors hardcoded
- Needs: Theme-aware colors for all elements

### 13. **post_screen.dart**
- Status: ⚠️ MINIMAL
- Issues:
  - Limited color usage but should verify all elements
- Needs: Quick review and updates if needed

### 14. **notifications_screen.dart**
- Status: ⚠️ PARTIAL
- Issues:
  - Text colors use hardcoded greys
  - Some elements may have hardcoded backgrounds
- Needs: Theme-aware text colors

### 15. **write_review_screen.dart**
- Status: ⚠️ UNKNOWN
- Needs: Full inspection and updates

### 16. **setting_screen.dart**
- Status: ⚠️ MINIMAL
- Issues:
  - Limited color usage but should verify
- Needs: Quick review

### 17. **privacy_policy.dart**
- Status: ⚠️ MINIMAL
- Issues:
  - Text colors hardcoded to `Colors.black54`
- Needs: Theme-aware text colors

---

## Priority Order for Updates

### HIGH PRIORITY (Most Used Screens)
1. **home_screen.dart** - Main browsing screen
2. **item_detail_screen.dart** - Item viewing screen
3. **messages_screen.dart** - Messaging list
4. **favorites_screen.dart** - Favorites list
5. **user_profile_screen.dart** - User profiles

### MEDIUM PRIORITY (Frequently Used)
6. **reviews_screen.dart** - Reviews list
7. **transaction_history_screen.dart** - Transaction history
8. **user_search_screen.dart** - User search
9. **chatsupport.dart** - Chat support

### LOW PRIORITY (Less Frequently Used)
10. **complete_profile_screen.dart** - Profile completion
11. **login.dart** - Login screen
12. **signup.dart** - Signup screen
13. **post_screen.dart** - Post creation
14. **notifications_screen.dart** - Notifications
15. **write_review_screen.dart** - Review writing
16. **setting_screen.dart** - Settings
17. **privacy_policy.dart** - Privacy policy

---

## Common Dark Mode Patterns to Apply

### For Scaffold Background
```dart
// Light mode
backgroundColor: Colors.grey[50]

// Dark mode
backgroundColor: Theme.of(context).scaffoldBackgroundColor
```

### For AppBar
```dart
// Light mode
backgroundColor: Colors.white
foregroundColor: Colors.black

// Dark mode
backgroundColor: Theme.of(context).appBarTheme.backgroundColor
foregroundColor: Theme.of(context).appBarTheme.foregroundColor
```

### For Cards
```dart
// Light mode
color: Colors.white

// Dark mode
color: Theme.of(context).cardColor
```

### For Text Colors
```dart
// Light mode
color: Colors.grey[600]

// Dark mode
color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)
```

### For Icons
```dart
// Light mode
color: Colors.grey[600]

// Dark mode
color: Theme.of(context).iconTheme.color
```

### For Shadows
```dart
// Light mode
color: Colors.grey.withOpacity(0.1)

// Dark mode
color: Colors.black.withOpacity(0.3)
```

---

## Notes
- All screens should use `Theme.of(context)` for colors instead of hardcoded values
- Preserve all accent colors (green, orange, blue, purple) as they are intentional
- Keep all logic and layout unchanged - only modify colors
- Test each screen in both light and dark modes after updates
