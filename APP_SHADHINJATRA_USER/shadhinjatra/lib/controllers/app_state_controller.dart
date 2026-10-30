import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shadhinjatra/services/auth_service.dart';

class AppStateController extends GetxController {
  static AppStateController get to => Get.find<AppStateController>();

  // Live Suspend State
  final RxBool isSuspended = false.obs;
  final RxString suspensionTitle = 'অ্যাকাউন্ট সাময়িকভাবে স্থগিত'.obs;
  final RxString suspensionReason =
      'নিরাপত্তা পর্যালোচনা বা নীতি লঙ্ঘনের কারণে আপনার অ্যাকাউন্ট সাময়িকভাবে স্থগিত করা হয়েছে। সহায়তার জন্য সাপোর্ট টিমের সাথে যোগাযোগ করুন।'
          .obs;
  final RxString supportPhone = '+8801900000000'.obs;
  final RxBool isChecking = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkLiveStatus();
  }

  Future<void> checkLiveStatus() async {
    isChecking.value = true;
    try {
      final res = await AuthService.fetchAccountData();
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final bool suspended = data['is_suspended'] == true ||
            data['verification_status'] == 'suspended' ||
            data['status'] == 'suspended';

        if (suspended) {
          isSuspended.value = true;
          if (data['suspension_reason'] != null) {
            suspensionReason.value = data['suspension_reason'].toString();
          }
        } else {
          isSuspended.value = false;
        }
      }
    } catch (e) {
      debugPrint('AppStateController checkLiveStatus error: $e');
    } finally {
      isChecking.value = false;
    }
  }

  void setSuspended(bool suspended, {String? title, String? reason, String? phone}) {
    isSuspended.value = suspended;
    if (title != null) suspensionTitle.value = title;
    if (reason != null) suspensionReason.value = reason;
    if (phone != null) supportPhone.value = phone;
  }

  void clearSuspension() {
    isSuspended.value = false;
  }
}
