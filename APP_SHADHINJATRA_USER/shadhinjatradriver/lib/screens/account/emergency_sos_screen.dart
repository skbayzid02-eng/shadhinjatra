import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';

class _SosLocalization {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      'app_bar_title': 'Safety & Emergency Support',
      'tab_sos': 'SOS & Emergency',
      'tab_tracking': 'Guardian & Tracking',
      'tab_reports': 'Reports & Helpline',
      'sos_active_banner': '🚨 Emergency alert active! Command center is monitoring your location.',
      'sos_headline': 'One-Tap Emergency Assistance',
      'sos_subheadline': 'Pressing the button below instantly transmits your live GPS coordinates to the safety command room and Police (999).',
      'sos_btn_label': '1-Tap Emergency Signal',
      'police_title': 'National Emergency Response (999)',
      'police_sub': 'Police, Ambulance & Fire Service',
      'call_999_btn': 'Call 999',
      'command_title': 'Shadhin Jatra Command Desk',
      'command_sub': '24/7 Dedicated Driver Safety Team',
      'command_btn': 'Command Room',
      'sos_dialog_title': 'Emergency Signal (SOS)',
      'sos_dialog_content': 'Do you want to send an immediate emergency alert to the safety command center and Police (999)?',
      'sos_note_hint': 'Emergency note / reason (optional)',
      'btn_cancel': 'Cancel',
      'btn_send_sos': 'Yes, Send Alert',
      'sos_success_title': '🚨 Emergency Alert Active!',
      'sos_success_msg': 'Emergency alert received at command room. Call Police 999 for immediate on-site response.',
      'btn_call_999': 'Call Police 999',
      'guardian_card_title': 'Emergency Contact (Guardian)',
      'guardian_empty': 'No guardian contact added yet. Add a number for instant emergency location alerts.',
      'btn_add_contact': 'Add Contact',
      'guardian_default_name': 'Family Guardian',
      'btn_alert_guardian': 'Send Instant Alert & Location to Guardian',
      'guardian_modal_title': 'Guardian Information',
      'guardian_name_label': 'Guardian Name',
      'guardian_phone_label': 'Mobile Number',
      'guardian_relation_label': 'Relationship',
      'btn_save_contact': 'Save Contact',
      'phone_required': 'Please enter mobile number',
      'contact_saved': 'Contact saved successfully',
      'guardian_alert_title': 'Alert Sent to Guardian',
      'guardian_alert_msg': 'Live location alert message prepared for guardian.',
      'btn_send_whatsapp_sms': 'Send via SMS / WhatsApp',
      'share_tracking_title': 'Share Live Location Tracking',
      'share_tracking_desc': 'Share a secure live tracking link with family or friends so they can view your vehicle speed and location in any browser.',
      'duration_selector': 'Select share duration:',
      'hours_suffix': 'hours',
      'link_active': 'Live link active',
      'expires_prefix': 'Expires: ',
      'link_copied': 'Tracking link copied to clipboard!',
      'btn_copy_link': 'Copy Link',
      'btn_whatsapp': 'WhatsApp',
      'btn_generate_link': 'Generate New Live Location Link',
      'report_passenger_title': 'Report Passenger',
      'report_passenger_sub': 'Report misbehavior, fake bookings or fare evasion.',
      'btn_report': 'Report',
      'report_passenger_dialog_title': 'Report Passenger',
      'category_label': 'Complaint Category',
      'passenger_info_label': 'Passenger Name / Phone (Optional)',
      'incident_desc_label': 'Incident Description',
      'incident_desc_hint': 'Describe where and how the incident occurred...',
      'btn_submit_report': 'Submit Complaint',
      'desc_required': 'Please enter description',
      'complaint_received_title': 'Complaint Received',
      'complaint_received_msg': 'Safety team will review the incident and take necessary action.',
      'btn_ok': 'OK',
      'report_safety_title': 'Report Safety Hazard',
      'report_safety_sub': 'Report road accidents, mechanical breakdowns or hazard zones.',
      'report_safety_dialog_title': 'Report Safety Hazard',
      'location_label': 'Location / Area',
      'safety_desc_hint': 'Describe what happened and what assistance is needed...',
      'btn_submit_safety': 'Send to Response Team',
      'safety_received_title': 'Sent to Response Team',
      'safety_received_msg': 'Safety response team will review the situation immediately.',
      'hotlines_title': '24/7 Emergency Support & Hotlines',
    },
    'bn': {
      'app_bar_title': 'নিরাপত্তা ও জরুরি সহায়তা (Safety & SOS)',
      'tab_sos': 'SOS ও জরুরি',
      'tab_tracking': 'অভিভাবক ও ট্র্যাকিং',
      'tab_reports': 'রিপোর্ট ও হেল্পলাইন',
      'sos_active_banner': '🚨 আপনার জরুরি সংকেত সক্রিয় রয়েছে! কমান্ড সেন্টার আপনার অবস্থানের ওপর নজর রাখছে।',
      'sos_headline': 'জরুরি বিপদে এক ট্যাপে সাহায্য চান',
      'sos_subheadline': 'নিচের বোতামে চাপলে কন্ট্রোল রুম এবং জরুরি সেবা পুলিশ (৯৯৯)-কে আপনার লাইভ জিপিএস লোকেশন সংকেত পাঠানো হবে।',
      'sos_btn_label': '১-ট্যাপ জরুরি সংকেত',
      'police_title': 'জাতীয় জরুরি সেবা হটলাইন',
      'police_sub': 'পুলিশ, অ্যাম্বুলেন্স ও ফায়ার সার্ভিস',
      'call_999_btn': 'কল ৯৯৯',
      'command_title': 'স্বাধীনযাত্রা কমান্ড ডেস্ক',
      'command_sub': '২৪/৭ চালক নিরাপত্তা টিম',
      'command_btn': 'কমান্ড রুম',
      'sos_dialog_title': 'জরুরি সংকেত (SOS)',
      'sos_dialog_content': 'আপনি কি স্বাধীনযাত্রা নিরাপত্তা কন্ট্রোল রুম ও পুলিশ (৯৯৯) কে তাৎক্ষণিক জরুরি অ্যালার্ট পাঠাতে চান?',
      'sos_note_hint': 'জরুরি কারণ লিখুন (ঐচ্ছিক)',
      'btn_cancel': 'বাতিল',
      'btn_send_sos': 'হ্যাঁ, সংকেত পাঠান',
      'sos_success_title': '🚨 জরুরি সংকেত সক্রিয়!',
      'sos_success_msg': 'জরুরি অ্যালার্ট নিরাপত্তা কন্ট্রোল রুমে পৌঁছেছে। পুলিশ ৯৯৯ এ কল করুন।',
      'btn_call_999': 'পুলিশ ৯৯৯ এ কল করুন',
      'guardian_card_title': 'জরুরি অভিভাবক (Emergency Contact)',
      'guardian_empty': 'কোনো অভিভাবকের নম্বর যুক্ত করা নেই। জরুরি পরিস্থিতিতে তাৎক্ষণিক অ্যালার্টের জন্য নম্বর যুক্ত করুন।',
      'btn_add_contact': 'যোগ করুন',
      'guardian_default_name': 'পারিবারিক অভিভাবক',
      'btn_alert_guardian': 'অভিভাবককে তাৎক্ষণিক অ্যালার্ট ও লোকেশন পাঠান',
      'guardian_modal_title': 'পারিবারিক অভিভাবক তথ্য',
      'guardian_name_label': 'অভিভাবকের নাম (Name)',
      'guardian_phone_label': 'মোবাইল নম্বর (Phone Number)',
      'guardian_relation_label': 'সম্পর্ক (Relation)',
      'btn_save_contact': 'সংরক্ষণ করুন (Save Contact)',
      'phone_required': 'অনুগ্রহ করে মোবাইল নম্বর প্রদান করুন',
      'contact_saved': 'তথ্য সংরক্ষিত হয়েছে',
      'guardian_alert_title': 'অভিভাবককে সতর্কবার্তা প্রেরিত',
      'guardian_alert_msg': 'অভিভাবকের ফোনে লাইভ লোকেশন সতর্কবার্তা প্রস্তুত হয়েছে।',
      'btn_send_whatsapp_sms': 'এসএমএস / WhatsApp এ পাঠান',
      'share_tracking_title': 'লাইভ লোকেশন ট্র্যাকিং শেয়ার',
      'share_tracking_desc': 'পরিবার বা বন্ধুদের সাথে নিরাপদ লাইভ ট্র্যাকিং লিংক শেয়ার করুন, যাতে তারা যেকোনো ব্রাউজার থেকে আপনার বর্তমান গাড়ির গতি ও অবস্থান দেখতে পায়।',
      'duration_selector': 'শেয়ারের মেয়াদ নির্বাচন করুন:',
      'hours_suffix': 'ঘণ্টা',
      'link_active': 'লাইভ লিংক সক্রিয়',
      'expires_prefix': 'মেয়াদ: ',
      'link_copied': 'ট্র্যাকিং লিংক ক্লিপবোর্ডে কপি হয়েছে!',
      'btn_copy_link': 'লিংক কপি',
      'btn_whatsapp': 'WhatsApp',
      'btn_generate_link': 'নতুন লাইভ লোকেশন লিংক তৈরি করুন',
      'report_passenger_title': 'Report Passenger (যাত্রী রিপোর্ট)',
      'report_passenger_sub': 'যাত্রীর অসদাচরণ, ভুয়া বুকিং বা ভাড়া ফাঁকি দিলে অভিযোগ জমা দিন।',
      'btn_report': 'রিপোর্ট',
      'report_passenger_dialog_title': 'যাত্রী রিপোর্ট করুন (Report Passenger)',
      'category_label': 'অভিযোগের ধরন (Category)',
      'passenger_info_label': 'যাত্রীর নাম / মোবাইল নম্বর (ঐচ্ছিক)',
      'incident_desc_label': 'ঘটনার বিবরণ লিখুন (Description)',
      'incident_desc_hint': 'ঘটনাটি কোথায় ও কীভাবে ঘটেছে বিস্তারিত লিখুন...',
      'btn_submit_report': 'অভিযোগ দাখিল করুন (Submit Report)',
      'desc_required': 'অনুগ্রহ করে ঘটনার বিবরণ লিখুন',
      'complaint_received_title': 'অভিযোগ গৃহীত হয়েছে',
      'complaint_received_msg': 'নিরাপত্তা টিম দ্রুত পর্যালোচনা করে ব্যবস্থা গ্রহণ করবে।',
      'btn_ok': 'ঠিক আছে',
      'report_safety_title': 'Report Safety Issue (নিরাপত্তা ঝুঁকি)',
      'report_safety_sub': 'সড়ক দুর্ঘটনা, যান্ত্রিক ত্রুটি বা ঝুঁকিপূর্ণ এলাকা রিপোর্ট করুন।',
      'report_safety_dialog_title': 'নিরাপত্তা ঝুঁকি রিপোর্ট (Safety Issue)',
      'location_label': 'ঘটনাস্থল / এলাকা (Location)',
      'safety_desc_hint': 'কী ঘটেছে এবং কী ধরনের তাৎক্ষণিক সহায়তা প্রয়োজন...',
      'btn_submit_safety': 'জরুরি রেসপন্স টিমে পাঠান',
      'safety_received_title': 'রেসপন্স টিমে পাঠানো হয়েছে',
      'safety_received_msg': 'নিরাপত্তা রেসপন্স দল অবিলম্বে পরিস্থিতি পর্যালোচনা করবে।',
      'hotlines_title': 'জরুরি হটলাইন ও সাপোর্ট ডেস্ক (24/7 Hotlines)',
    },
    'ar': {
      'app_bar_title': 'السلامة والدعم في حالات الطوارئ',
      'tab_sos': 'الطوارئ وSOS',
      'tab_tracking': 'ولي الأمر والتتبع',
      'tab_reports': 'البلاغات وخطوط المساعدة',
      'sos_active_banner': '🚨 إشارة الطوارئ نشطة! مركز القيادة يراقب موقعك الآن.',
      'sos_headline': 'طلب المساعدة بضغطة زر عند الطوارئ',
      'sos_subheadline': 'الضغط على الزر أدناه يرسل إحداثيات موقعك المباشر فوراً إلى غرفة التحكم وشرطة الطوارئ 999.',
      'sos_btn_label': 'إشارة طوارئ بلمسة واحدة',
      'police_title': 'خدمة الطوارئ الوطنية (999)',
      'police_sub': 'الشرطة، الإسعاف والدفاع المدني',
      'call_999_btn': 'اتصال 999',
      'command_title': 'مكتب قيادة شادهين جاترا',
      'command_sub': 'فريق أمان السائقين على مدار الساعة',
      'command_btn': 'غرفة القيادة',
      'sos_dialog_title': 'إشارة طوارئ (SOS)',
      'sos_dialog_content': 'هل تريد إرسال تنبيه طوارئ فوري إلى غرفة التحكم والشرطة 999؟',
      'sos_note_hint': 'سبب الطوارئ (اختياري)',
      'btn_cancel': 'إلغاء',
      'btn_send_sos': 'نعم، أرسل التنبيه',
      'sos_success_title': '🚨 تم تفعيل إشارة الطوارئ!',
      'sos_success_msg': 'تم استلام التنبيه بغرفة التحكم. يرجى الاتصال برقم 999 للاستجابة الميدانية.',
      'btn_call_999': 'اتصال بالشرطة 999',
      'guardian_card_title': 'جهة اتصال الطوارئ (ولي الأمر)',
      'guardian_empty': 'لم تتم إضافة جهة اتصال. أضف رقمًا لتنبيهات الطوارئ الفورية.',
      'btn_add_contact': 'إضافة جهة اتصال',
      'guardian_default_name': 'ولي الأمر',
      'btn_alert_guardian': 'إرسال تنبيه فوري بالموقع إلى ولي الأمر',
      'guardian_modal_title': 'بيانات ولي الأمر',
      'guardian_name_label': 'اسم ولي الأمر',
      'guardian_phone_label': 'رقم الجوال',
      'guardian_relation_label': 'صلة القرابة',
      'btn_save_contact': 'حفظ جهة الاتصال',
      'phone_required': 'يرجى إدخال رقم الجوال',
      'contact_saved': 'تم حفظ بيانات الاتصال بنجاح',
      'guardian_alert_title': 'تم إرسال التنبيه إلى ولي الأمر',
      'guardian_alert_msg': 'تم تجهيز رسالة التتبع المباشر لولي الأمر.',
      'btn_send_whatsapp_sms': 'إرسال عبر واتساب / رسالة نصية',
      'share_tracking_title': 'مشاركة الموقع المباشر',
      'share_tracking_desc': 'شارك رابط تتبع مباشر مع العائلة أو الأصدقاء لمشاهدة موقع المركبة وسرعتها عبر أي متصفح.',
      'duration_selector': 'اختر مدة المشاركة:',
      'hours_suffix': 'ساعات',
      'link_active': 'الرابط المباشر نشط',
      'expires_prefix': 'الانتهاء: ',
      'link_copied': 'تم نسخ رابط التتبع!',
      'btn_copy_link': 'نسخ الرابط',
      'btn_whatsapp': 'واتساب',
      'btn_generate_link': 'إنشاء رابط تتبع مباشر جديد',
      'report_passenger_title': 'الإبلاغ عن راكب',
      'report_passenger_sub': 'الإبلاغ عن سوء السلوك أو الحجوزات الوهمية أو عدم دفع الأجرة.',
      'btn_report': 'إبلاغ',
      'report_passenger_dialog_title': 'الإبلاغ عن راكب',
      'category_label': 'نوع الشكوى',
      'passenger_info_label': 'اسم الراكب / رقم الجوال (اختياري)',
      'incident_desc_label': 'تفاصيل ما حدث',
      'incident_desc_hint': 'يرجى كتابة تفاصيل الواقعة ومكان حدوثها...',
      'btn_submit_report': 'إرسال البلاغ',
      'desc_required': 'يرجى كتابة تفاصيل الحادث',
      'complaint_received_title': 'تم استلام الشكوى',
      'complaint_received_msg': 'سيقوم فريق الأمان بمراجعة البلاغ واتخاذ الإجراء اللازم.',
      'btn_ok': 'حسناً',
      'report_safety_title': 'الإبلاغ عن خطر أمني',
      'report_safety_sub': 'الإبلاغ عن حوادث الطرق أو الأعطال أو المناطق الخطرة.',
      'report_safety_dialog_title': 'الإبلاغ عن خطر أمني',
      'location_label': 'الموقع / المنطقة',
      'safety_desc_hint': 'ماذا حدث ونوع المساعدة المطلوبة...',
      'btn_submit_safety': 'إرسال إلى فريق الاستجابة',
      'safety_received_title': 'تم الإرسال إلى فريق الاستجابة',
      'safety_received_msg': 'سيقوم فريق الاستجابة بمتابعة الموقف فوراً.',
      'hotlines_title': 'خطوط الطوارئ والدعم 24/7',
    },
    'hi': {
      'app_bar_title': 'सुरक्षा और आपातकालीन सहायता',
      'tab_sos': 'SOS और आपातकाल',
      'tab_tracking': 'अभिभावक और ट्रैकिंग',
      'tab_reports': 'रिपोर्ट और हेल्पलाइन',
      'sos_active_banner': '🚨 आपातकालीन संकेत सक्रिय है! कमांड सेंटर आपके स्थान की निगरानी कर रहा है।',
      'sos_headline': 'एक टैप में आपातकालीन सहायता',
      'sos_subheadline': 'नीचे दिए गए बटन को दबाने से सुरक्षा कमांड रूम और पुलिस (999) को आपका लाइव जीपीएस स्थान भेजा जाएगा।',
      'sos_btn_label': '1-टैप आपातकालीन संकेत',
      'police_title': 'राष्ट्रीय आपातकालीन हेल्पलाइन (999)',
      'police_sub': 'पुलिस, एम्बुलेंस और फायर सर्विस',
      'call_999_btn': 'कॉल 999',
      'command_title': 'स्वाधीन जात्रा कमांड डेस्क',
      'command_sub': '24/7 समर्पित चालक सुरक्षा टीम',
      'command_btn': 'कमांड रूम',
      'sos_dialog_title': 'आपातकालीन संकेत (SOS)',
      'sos_dialog_content': 'क्या आप सुरक्षा कमांड रूम और पुलिस (999) को तत्काल आपातकालीन अलर्ट भेजना चाहते हैं?',
      'sos_note_hint': 'आपातकालीन कारण (वैकल्पिक)',
      'btn_cancel': 'रद्द करें',
      'btn_send_sos': 'हाँ, संकेत भेजें',
      'sos_success_title': '🚨 आपातकालीन संकेत सक्रिय!',
      'sos_success_msg': 'आपातकालीन अलर्ट सुरक्षा कमांड रूम में पहुँच गया है। पुलिस 999 पर कॉल करें।',
      'btn_call_999': 'पुलिस 999 पर कॉल करें',
      'guardian_card_title': 'आपातकालीन अभिभावक',
      'guardian_empty': 'कोई अभिभावक नंबर नहीं जुड़ा है। तत्काल अलर्ट के लिए नंबर जोड़ें।',
      'btn_add_contact': 'जोड़ें',
      'guardian_default_name': 'पारिवारिक अभिभावक',
      'btn_alert_guardian': 'अभिभावक को तत्काल अलर्ट और स्थान भेजें',
      'guardian_modal_title': 'अभिभावक की जानकारी',
      'guardian_name_label': 'अभिभावक का नाम',
      'guardian_phone_label': 'मोबाइल नंबर',
      'guardian_relation_label': 'संबंध',
      'btn_save_contact': 'सहेजें',
      'phone_required': 'कृपया मोबाइल नंबर दर्ज करें',
      'contact_saved': 'जानकारी सहेजी गई',
      'guardian_alert_title': 'अभिभावक को अलर्ट भेजा गया',
      'guardian_alert_msg': 'अभिभावक के लिए लाइव लोकेशन अलर्ट तैयार किया गया है।',
      'btn_send_whatsapp_sms': 'SMS / WhatsApp पर भेजें',
      'share_tracking_title': 'लाइव लोकेशन ट्रैकिंग शेयर करें',
      'share_tracking_desc': 'सुरक्षित लाइव ट्रैकिंग लिंक परिवार या दोस्तों के साथ साझा करें।',
      'duration_selector': 'साझा करने की अवधि चुनें:',
      'hours_suffix': 'घंटे',
      'link_active': 'लाइव लिंक सक्रिय',
      'expires_prefix': 'समाप्ति: ',
      'link_copied': 'ट्रैकिंग लिंक कॉपी कर लिया गया है!',
      'btn_copy_link': 'लिंक कॉपी करें',
      'btn_whatsapp': 'WhatsApp',
      'btn_generate_link': 'नया लाइव लोकेशन लिंक बनाएं',
      'report_passenger_title': 'यात्री की रिपोर्ट करें',
      'report_passenger_sub': 'दुर्व्यवहार या किराया न देने पर शिकायत दर्ज करें।',
      'btn_report': 'रिपोर्ट',
      'report_passenger_dialog_title': 'यात्री की रिपोर्ट करें',
      'category_label': 'शिकायत का प्रकार',
      'passenger_info_label': 'यात्री का नाम / फोन (वैकल्पिक)',
      'incident_desc_label': 'घटना का विवरण',
      'incident_desc_hint': 'विस्तार से बताएं कि घटना कहाँ और कैसे हुई...',
      'btn_submit_report': 'शिकायत दर्ज करें',
      'desc_required': 'कृपया विवरण लिखें',
      'complaint_received_title': 'शिकायत प्राप्त हुई',
      'complaint_received_msg': 'सुरक्षा टीम मामले की समीक्षा कर कार्रवाई करेगी।',
      'btn_ok': 'ठीक है',
      'report_safety_title': 'सुरक्षा जोखिम की रिपोर्ट करें',
      'report_safety_sub': 'सड़क दुर्घटना या खतरनाक क्षेत्र की रिपोर्ट करें।',
      'report_safety_dialog_title': 'सुरक्षा जोखिम रिपोर्ट',
      'location_label': 'घटनास्थल / क्षेत्र',
      'safety_desc_hint': 'क्या हुआ और किस सहायता की आवश्यकता है...',
      'btn_submit_safety': 'रिस्पॉन्स टीम को भेजें',
      'safety_received_title': 'रिस्पॉन्स टीम को भेजा गया',
      'safety_received_msg': 'सुरक्षा टीम तत्काल स्थिति की समीक्षा करेगी।',
      'hotlines_title': '24/7 आपातकालीन हेल्पलाइन',
    },
    'es': {
      'app_bar_title': 'Seguridad y Soporte de Emergencia',
      'tab_sos': 'SOS y Emergencia',
      'tab_tracking': 'Tutor y Seguimiento',
      'tab_reports': 'Reportes y Líneas de Ayuda',
      'sos_active_banner': '🚨 ¡Alerta activa! La central monitorea su ubicación.',
      'sos_headline': 'Asistencia de Emergencia en 1 Toque',
      'sos_subheadline': 'Al presionar el botón se enviará su ubicación GPS en vivo a la central y a la Policía (999).',
      'sos_btn_label': 'Señal de Emergencia 1-Toque',
      'police_title': 'Respuesta Nacional de Emergencia (999)',
      'police_sub': 'Policía, Ambulancia y Bomberos',
      'call_999_btn': 'Llamar al 999',
      'command_title': 'Mesa de Comando Shadhin Jatra',
      'command_sub': 'Equipo de Seguridad 24/7 para Conductores',
      'command_btn': 'Central',
      'sos_dialog_title': 'Señal de Emergencia (SOS)',
      'sos_dialog_content': '¿Desea enviar una alerta de emergencia a la central y a la Policía (999)?',
      'sos_note_hint': 'Motivo de emergencia (opcional)',
      'btn_cancel': 'Cancelar',
      'btn_send_sos': 'Sí, Enviar Alerta',
      'sos_success_title': '🚨 ¡Alerta de Emergencia Activa!',
      'sos_success_msg': 'Alerta recibida en la central. Llame al 999 para asistencia policial.',
      'btn_call_999': 'Llamar al 999',
      'guardian_card_title': 'Contacto de Emergencia (Tutor)',
      'guardian_empty': 'Sin contacto asignado. Añada uno para alertas inmediatas.',
      'btn_add_contact': 'Añadir Contacto',
      'guardian_default_name': 'Tutor Familiar',
      'btn_alert_guardian': 'Enviar Alerta y Ubicación al Tutor',
      'guardian_modal_title': 'Datos del Tutor',
      'guardian_name_label': 'Nombre',
      'guardian_phone_label': 'Teléfono Móvil',
      'guardian_relation_label': 'Parentesco',
      'btn_save_contact': 'Guardar',
      'phone_required': 'Ingrese número de teléfono',
      'contact_saved': 'Contacto guardado',
      'guardian_alert_title': 'Alerta Enviada al Tutor',
      'guardian_alert_msg': 'Mensaje con ubicación preparado para el tutor.',
      'btn_send_whatsapp_sms': 'Enviar por SMS / WhatsApp',
      'share_tracking_title': 'Compartir Ubicación en Vivo',
      'share_tracking_desc': 'Comparta un enlace seguro para que sigan su recorrido.',
      'duration_selector': 'Seleccione duración:',
      'hours_suffix': 'horas',
      'link_active': 'Enlace activo',
      'expires_prefix': 'Vence: ',
      'link_copied': '¡Enlace copiado al portapapeles!',
      'btn_copy_link': 'Copiar Enlace',
      'btn_whatsapp': 'WhatsApp',
      'btn_generate_link': 'Generar Nuevo Enlace',
      'report_passenger_title': 'Reportar Pasajero',
      'report_passenger_sub': 'Reporte mala conducta o falta de pago.',
      'btn_report': 'Reportar',
      'report_passenger_dialog_title': 'Reportar Pasajero',
      'category_label': 'Categoría',
      'passenger_info_label': 'Nombre / Teléfono del Pasajero (Opcional)',
      'incident_desc_label': 'Descripción',
      'incident_desc_hint': 'Describa lo sucedido...',
      'btn_submit_report': 'Enviar Reporte',
      'desc_required': 'Ingrese una descripción',
      'complaint_received_title': 'Reporte Recibido',
      'complaint_received_msg': 'El equipo de seguridad evaluará el caso.',
      'btn_ok': 'Aceptar',
      'report_safety_title': 'Reportar Peligro Vial',
      'report_safety_sub': 'Reporte accidentes o zonas peligrosas.',
      'report_safety_dialog_title': 'Reportar Peligro Vial',
      'location_label': 'Ubicación',
      'safety_desc_hint': 'Qué ocurrió y qué ayuda requiere...',
      'btn_submit_safety': 'Enviar a Respuesta Inmediata',
      'safety_received_title': 'Enviado al Equipo de Respuesta',
      'safety_received_msg': 'El equipo evaluará la situación inmediatamente.',
      'hotlines_title': 'Líneas de Emergencia 24/7',
    },
    'fr': {
      'app_bar_title': 'Sécurité et Assistance d\'Urgence',
      'tab_sos': 'SOS & Urgence',
      'tab_tracking': 'Proche & Suivi',
      'tab_reports': 'Signalements & Urgences',
      'sos_active_banner': '🚨 Signal d\'urgence actif ! Le centre surveille votre position.',
      'sos_headline': 'Assistance d\'Urgence en 1 Clic',
      'sos_subheadline': 'Appuyez pour envoyer vos coordonnées GPS en direct au centre et à la police (999).',
      'sos_btn_label': 'Signal d\'Urgence 1 Clic',
      'police_title': 'Urgences Nationales (999)',
      'police_sub': 'Police, Ambulance et Pompiers',
      'call_999_btn': 'Appeler le 999',
      'command_title': 'Poste de Contrôle Shadhin Jatra',
      'command_sub': 'Équipe de Sécurité des Chauffeurs 24h/24',
      'command_btn': 'Poste de Contrôle',
      'sos_dialog_title': 'Signal d\'Urgence (SOS)',
      'sos_dialog_content': 'Envoyer une alerte d\'urgence au poste de contrôle et à la police (999) ?',
      'sos_note_hint': 'Motif d\'urgence (facultatif)',
      'btn_cancel': 'Annuler',
      'btn_send_sos': 'Oui, Envoyer',
      'sos_success_title': '🚨 Alerte d\'Urgence Active !',
      'sos_success_msg': 'Alerte transmise. Appelez le 999 pour intervention policière.',
      'btn_call_999': 'Appeler le 999',
      'guardian_card_title': 'Contact d\'Urgence (Proche)',
      'guardian_empty': 'Aucun contact enregistré. Ajoutez un proche pour alertes directes.',
      'btn_add_contact': 'Ajouter',
      'guardian_default_name': 'Contact Proche',
      'btn_alert_guardian': 'Alerter le Proche avec Position en Direct',
      'guardian_modal_title': 'Coordonnées du Proche',
      'guardian_name_label': 'Nom',
      'guardian_phone_label': 'Numéro de Mobile',
      'guardian_relation_label': 'Lien de Parenté',
      'btn_save_contact': 'Enregistrer',
      'phone_required': 'Veuillez saisir un numéro',
      'contact_saved': 'Contact enregistré',
      'guardian_alert_title': 'Alerte Envoyée au Proche',
      'guardian_alert_msg': 'Message de suivi en direct prêt.',
      'btn_send_whatsapp_sms': 'Envoyer par SMS / WhatsApp',
      'share_tracking_title': 'Partager la Position en Direct',
      'share_tracking_desc': 'Partagez un lien sécurisé permettant de suivre votre trajet.',
      'duration_selector': 'Durée du partage :',
      'hours_suffix': 'heures',
      'link_active': 'Lien actif',
      'expires_prefix': 'Expire : ',
      'link_copied': 'Lien copié dans le presse-papiers !',
      'btn_copy_link': 'Copier le Lien',
      'btn_whatsapp': 'WhatsApp',
      'btn_generate_link': 'Générer un Nouveau Lien',
      'report_passenger_title': 'Signaler un Passager',
      'report_passenger_sub': 'Signalez un comportement abusif ou un non-paiement.',
      'btn_report': 'Signaler',
      'report_passenger_dialog_title': 'Signaler un Passager',
      'category_label': 'Catégorie',
      'passenger_info_label': 'Nom / Numéro du Passager (Facultatif)',
      'incident_desc_label': 'Description',
      'incident_desc_hint': 'Décrivez ce qui s\'est passé...',
      'btn_submit_report': 'Envoyer le Signalement',
      'desc_required': 'Description requise',
      'complaint_received_title': 'Signalement Enregistré',
      'complaint_received_msg': 'L\'équipe de sécurité examinera la situation.',
      'btn_ok': 'OK',
      'report_safety_title': 'Signaler un Danger',
      'report_safety_sub': 'Signalez un accident ou une zone à risque.',
      'report_safety_dialog_title': 'Signaler un Danger',
      'location_label': 'Lieu',
      'safety_desc_hint': 'Précisez le problème rencontré...',
      'btn_submit_safety': 'Transmettre à l\'Équipe d\'Intervention',
      'safety_received_title': 'Transmis à l\'Équipe d\'Intervention',
      'safety_received_msg': 'L\'équipe interviendra immédiatement.',
      'hotlines_title': 'Lignes d\'Urgence 24h/24',
    },
    'zh': {
      'app_bar_title': '安全防护与紧急求助',
      'tab_sos': '一键SOS求助',
      'tab_tracking': '紧急联系人与实时追踪',
      'tab_reports': '风险上报与热线',
      'sos_active_banner': '🚨 紧急报警已启动！调度中心正对您的位置进行实时监控。',
      'sos_headline': '遭遇危险 一键紧急求助',
      'sos_subheadline': '点击下方按钮将立即向安全指挥调度中心及报警热线 999 发送您的实时定位。',
      'sos_btn_label': '一键发送紧急信号',
      'police_title': '国家紧急救援热线 (999)',
      'police_sub': '警察、医疗急救与消防救援',
      'call_999_btn': '拨打 999',
      'command_title': '独立出行指挥中心专线',
      'command_sub': '全天候 24/7 司机安全保障团队',
      'command_btn': '调度中心',
      'sos_dialog_title': '紧急报警信号 (SOS)',
      'sos_dialog_content': '确认立即向安全调度中心与 999 警方发送紧急遇险警报吗？',
      'sos_note_hint': '紧急说明（选填）',
      'btn_cancel': '取消',
      'btn_send_sos': '确认发送',
      'sos_success_title': '🚨 紧急警报已生效！',
      'sos_success_msg': '警报已传达至调度中心，请同时拨打 999 获取出警支持。',
      'btn_call_999': '立即拨打 999',
      'guardian_card_title': '紧急联系人 (家属/监护人)',
      'guardian_empty': '暂未绑定紧急联系人，建议尽快添加以便突发状况时一键通知。',
      'btn_add_contact': '添加联系人',
      'guardian_default_name': '家庭联系人',
      'btn_alert_guardian': '向联系人发送位置与预警',
      'guardian_modal_title': '紧急联系人信息',
      'guardian_name_label': '姓名',
      'guardian_phone_label': '手机号码',
      'guardian_relation_label': '关系',
      'btn_save_contact': '保存联系人',
      'phone_required': '请输入手机号码',
      'contact_saved': '信息保存成功',
      'guardian_alert_title': '已向联系人发送预警',
      'guardian_alert_msg': '包含实时追踪链接的预警信息已生成。',
      'btn_send_whatsapp_sms': '通过短信或微信/WhatsApp发送',
      'share_tracking_title': '分享实时行程位置',
      'share_tracking_desc': '分享专属加密行程链接，家人可通过任意浏览器查看车辆实时轨迹与车速。',
      'duration_selector': '选择分享时长：',
      'hours_suffix': '小时',
      'link_active': '行程实时链接已激活',
      'expires_prefix': '有效期至: ',
      'link_copied': '追踪链接已复制到剪贴板！',
      'btn_copy_link': '复制链接',
      'btn_whatsapp': 'WhatsApp',
      'btn_generate_link': '生成新追踪链接',
      'report_passenger_title': '举报乘客违规',
      'report_passenger_sub': '上报乘客言语辱骂、虚假叫车或逃单逃费行为。',
      'btn_report': '立即举报',
      'report_passenger_dialog_title': '乘客违规行为上报',
      'category_label': '违规类别',
      'passenger_info_label': '乘客姓名/手机号 (选填)',
      'incident_desc_label': '事件具体经过',
      'incident_desc_hint': '请说明发生地点及详细情况...',
      'btn_submit_report': '提交举报',
      'desc_required': '请填写事件详细描述',
      'complaint_received_title': '投诉举报已受理',
      'complaint_received_msg': '安全团队将立即介入调查并做出相应处理。',
      'btn_ok': '确定',
      'report_safety_title': '上报道路安全隐患',
      'report_safety_sub': '上报严重车祸、车辆故障抛锚或治安高危区域。',
      'report_safety_dialog_title': '道路安全隐患上报',
      'location_label': '具体地点/区域',
      'safety_desc_hint': '请说明现场状况及所需紧急协助...',
      'btn_submit_safety': '上报应急处理组',
      'safety_received_title': '已转交应急处理组',
      'safety_received_msg': '应急保障部门将立即开展现场协同处置。',
      'hotlines_title': '全天候 24/7 救援热线专区',
    },
    'pt': {
      'app_bar_title': 'Segurança e Suporte de Emergência',
      'tab_sos': 'SOS e Emergência',
      'tab_tracking': 'Contato e Rastreamento',
      'tab_reports': 'Relatos e Linhas de Ajuda',
      'sos_active_banner': '🚨 Alerta ativo! A central está monitorando sua localização.',
      'sos_headline': 'Ajuda Emergencial em 1 Toque',
      'sos_subheadline': 'O botão enviará suas coordenadas de GPS em tempo real à central e à Polícia (999).',
      'sos_btn_label': 'Sinal de Emergência 1 Toque',
      'police_title': 'Emergência Nacional (999)',
      'police_sub': 'Polícia, Ambulância e Bombeiros',
      'call_999_btn': 'Ligar 999',
      'command_title': 'Central Shadhin Jatra',
      'command_sub': 'Segurança do Motorista 24/7',
      'command_btn': 'Central',
      'sos_dialog_title': 'Sinal de Emergência (SOS)',
      'sos_dialog_content': 'Deseja enviar alerta imediato à central e à polícia (999)?',
      'sos_note_hint': 'Motivo da emergência (opcional)',
      'btn_cancel': 'Cancelar',
      'btn_send_sos': 'Sim, Enviar Alerta',
      'sos_success_title': '🚨 Alerta Ativo!',
      'sos_success_msg': 'Alerta recebido na central. Ligue para 999 para apoio no local.',
      'btn_call_999': 'Ligar 999',
      'guardian_card_title': 'Contato de Emergência (Guardião)',
      'guardian_empty': 'Nenhum contato adicionado. Adicione para alertas imediatos.',
      'btn_add_contact': 'Adicionar',
      'guardian_default_name': 'Contato de Emergência',
      'btn_alert_guardian': 'Enviar Alerta com Localização ao Contato',
      'guardian_modal_title': 'Dados do Contato',
      'guardian_name_label': 'Nome',
      'guardian_phone_label': 'Telefone',
      'guardian_relation_label': 'Grau de Parentesco',
      'btn_save_contact': 'Salvar',
      'phone_required': 'Informe o telefone',
      'contact_saved': 'Contato salvo',
      'guardian_alert_title': 'Alerta Enviado',
      'guardian_alert_msg': 'Mensagem com link de rastreamento preparada.',
      'btn_send_whatsapp_sms': 'Enviar via SMS / WhatsApp',
      'share_tracking_title': 'Compartilhar Localização em Tempo Real',
      'share_tracking_desc': 'Compartilhe um link seguro para visualizarem sua rota.',
      'duration_selector': 'Duração do compartilhamento:',
      'hours_suffix': 'horas',
      'link_active': 'Link ativo',
      'expires_prefix': 'Validade: ',
      'link_copied': 'Link copiado para a área de transferência!',
      'btn_copy_link': 'Copiar Link',
      'btn_whatsapp': 'WhatsApp',
      'btn_generate_link': 'Gerar Novo Link',
      'report_passenger_title': 'Denunciar Passageiro',
      'report_passenger_sub': 'Denuncie mau comportamento ou calote.',
      'btn_report': 'Denunciar',
      'report_passenger_dialog_title': 'Denunciar Passageiro',
      'category_label': 'Categoria',
      'passenger_info_label': 'Nome / Telefone do Passageiro (Opcional)',
      'incident_desc_label': 'Descrição',
      'incident_desc_hint': 'Descreva o que aconteceu...',
      'btn_submit_report': 'Enviar Denúncia',
      'desc_required': 'Informe a descrição',
      'complaint_received_title': 'Denúncia Recebida',
      'complaint_received_msg': 'A equipe de segurança analisará o caso.',
      'btn_ok': 'OK',
      'report_safety_title': 'Relatar Risco na Via',
      'report_safety_sub': 'Relate acidentes ou áreas perigosas.',
      'report_safety_dialog_title': 'Relatar Risco na Via',
      'location_label': 'Local',
      'safety_desc_hint': 'O que houve e que assistência é necessária...',
      'btn_submit_safety': 'Enviar para a Equipe de Resposta',
      'safety_received_title': 'Enviado à Equipe de Resposta',
      'safety_received_msg': 'A equipe analisará imediatamente.',
      'hotlines_title': 'Linhas de Emergência 24/7',
    },
    'ru': {
      'app_bar_title': 'Безопасность и экстренная помощь',
      'tab_sos': 'SOS и помощь',
      'tab_tracking': 'Контакты и трекинг',
      'tab_reports': 'Жалобы и горячие линии',
      'sos_active_banner': '🚨 Сигнал тревоги активен! Командный центр отслеживает ваше местоположение.',
      'sos_headline': 'Помощь в один клик',
      'sos_subheadline': 'Кнопка немедленно передаст координаты GPS в ситуационный центр и полицию (999).',
      'sos_btn_label': 'SOS сигнал тревоги',
      'police_title': 'Служба экстренного реагирования (999)',
      'police_sub': 'Полиция, скорая помощь и пожарные',
      'call_999_btn': 'Вызов 999',
      'command_title': 'Диспетчерский центр Shadhin Jatra',
      'command_sub': 'Круглосуточная служба безопасности водителей',
      'command_btn': 'Диспетчер',
      'sos_dialog_title': 'Экстренный сигнал (SOS)',
      'sos_dialog_content': 'Отправить экстренный сигнал тревоги в центр безопасности и полицию (999)?',
      'sos_note_hint': 'Причина тревоги (необязательно)',
      'btn_cancel': 'Отмена',
      'btn_send_sos': 'Да, отправить',
      'sos_success_title': '🚨 Тревожный сигнал активен!',
      'sos_success_msg': 'Сигнал получен. Позвоните 999 для вызова наряда полиции.',
      'btn_call_999': 'Позвонить 999',
      'guardian_card_title': 'Экстренный контакт (Близкий)',
      'guardian_empty': 'Контакт не добавлен. Добавьте номер для быстрой отправки координат.',
      'btn_add_contact': 'Добавить',
      'guardian_default_name': 'Доверенное лицо',
      'btn_alert_guardian': 'Отправить координаты доверенному лицу',
      'guardian_modal_title': 'Данные контакта',
      'guardian_name_label': 'Имя',
      'guardian_phone_label': 'Телефон',
      'guardian_relation_label': 'Кем приходится',
      'btn_save_contact': 'Сохранить',
      'phone_required': 'Укажите номер телефона',
      'contact_saved': 'Контакт сохранен',
      'guardian_alert_title': 'Оповещение отправлено',
      'guardian_alert_msg': 'Сообщение с геопозицией сформировано.',
      'btn_send_whatsapp_sms': 'Отправить через SMS / WhatsApp',
      'share_tracking_title': 'Поделиться геолокацией поездки',
      'share_tracking_desc': 'Поделитесь ссылкой, чтобы близкие видели скорость и маршрут автомобиля.',
      'duration_selector': 'Длительность доступа:',
      'hours_suffix': 'ч.',
      'link_active': 'Ссылка активна',
      'expires_prefix': 'Истекает: ',
      'link_copied': 'Ссылка скопирована в буфер обмена!',
      'btn_copy_link': 'Копировать',
      'btn_whatsapp': 'WhatsApp',
      'btn_generate_link': 'Создать новую ссылку',
      'report_passenger_title': 'Пожаловаться на пассажира',
      'report_passenger_sub': 'Сообщите о грубости, ложном вызове или неоплате.',
      'btn_report': 'Жалоба',
      'report_passenger_dialog_title': 'Жалоба на пассажира',
      'category_label': 'Категория',
      'passenger_info_label': 'Имя / Телефон пассажира (необязательно)',
      'incident_desc_label': 'Описание ситуации',
      'incident_desc_hint': 'Опишите, где и что произошло...',
      'btn_submit_report': 'Отправить жалобу',
      'desc_required': 'Укажите описание ситуации',
      'complaint_received_title': 'Жалоба принята',
      'complaint_received_msg': 'Служба безопасности проверит обстоятельства.',
      'btn_ok': 'ОК',
      'report_safety_title': 'Сообщить об опасности на дороге',
      'report_safety_sub': 'ДТП, поломка или опасный участок.',
      'report_safety_dialog_title': 'Сообщить об опасности',
      'location_label': 'Местоположение',
      'safety_desc_hint': 'Что произошло и какая помощь требуется...',
      'btn_submit_safety': 'Отправить в службу реагирования',
      'safety_received_title': 'Передано службе реагирования',
      'safety_received_msg': 'Группа быстрого реагирования оценит ситуацию.',
      'hotlines_title': 'Круглосуточные горячие линии 24/7',
    },
    'id': {
      'app_bar_title': 'Keamanan & Bantuan Darurat',
      'tab_sos': 'SOS & Darurat',
      'tab_tracking': 'Keluarga & Pelacakan',
      'tab_reports': 'Laporan & Bantuan',
      'sos_active_banner': '🚨 Sinyal darurat aktif! Pusat komando memantau lokasi Anda.',
      'sos_headline': 'Bantuan Darurat 1 Sentuhan',
      'sos_subheadline': 'Menekan tombol ini akan mengirimkan koordinat GPS langsung ke pusat komando dan Kepolisian (999).',
      'sos_btn_label': 'Sinyal Darurat 1 Sentuhan',
      'police_title': 'Layanan Darurat Nasional (999)',
      'police_sub': 'Polisi, Ambulans, dan Pemadam Kebakaran',
      'call_999_btn': 'Panggil 999',
      'command_title': 'Pusat Kendali Shadhin Jatra',
      'command_sub': 'Tim Keamanan Pengemudi 24/7',
      'command_btn': 'Ruang Kendali',
      'sos_dialog_title': 'Sinyal Darurat (SOS)',
      'sos_dialog_content': 'Kirim peringatan darurat ke ruang kendali dan kepolisian 999?',
      'sos_note_hint': 'Catatan darurat (opsional)',
      'btn_cancel': 'Batal',
      'btn_send_sos': 'Ya, Kirim',
      'sos_success_title': '🚨 Sinyal Darurat Aktif!',
      'sos_success_msg': 'Peringatan diterima di ruang kendali. Hubungi 999 untuk respon polisi.',
      'btn_call_999': 'Panggil Polisi 999',
      'guardian_card_title': 'Kontak Darurat (Keluarga)',
      'guardian_empty': 'Belum ada kontak terdaftar. Tambahkan untuk peringatan darurat instan.',
      'btn_add_contact': 'Tambah Kontak',
      'guardian_default_name': 'Keluarga Terdekat',
      'btn_alert_guardian': 'Kirim Peringatan & Lokasi ke Keluarga',
      'guardian_modal_title': 'Data Kontak Darurat',
      'guardian_name_label': 'Nama',
      'guardian_phone_label': 'Nomor Ponsel',
      'guardian_relation_label': 'Hubungan',
      'btn_save_contact': 'Simpan',
      'phone_required': 'Masukkan nomor ponsel',
      'contact_saved': 'Kontak berhasil disimpan',
      'guardian_alert_title': 'Peringatan Terkirim',
      'guardian_alert_msg': 'Pesan pelacakan lokasi telah disiapkan.',
      'btn_send_whatsapp_sms': 'Kirim via SMS / WhatsApp',
      'share_tracking_title': 'Bagikan Pelacakan Langsung',
      'share_tracking_desc': 'Bagikan tautan pelacakan aman agar keluarga dapat memantau rute Anda.',
      'duration_selector': 'Pilih durasi:',
      'hours_suffix': 'jam',
      'link_active': 'Tautan aktif',
      'expires_prefix': 'Berakhir: ',
      'link_copied': 'Tautan pelacakan disalin!',
      'btn_copy_link': 'Salin Tautan',
      'btn_whatsapp': 'WhatsApp',
      'btn_generate_link': 'Buat Tautan Baru',
      'report_passenger_title': 'Laporkan Penumpang',
      'report_passenger_sub': 'Laporkan perilaku buruk atau penolakan bayar ongkos.',
      'btn_report': 'Lapor',
      'report_passenger_dialog_title': 'Laporkan Penumpang',
      'category_label': 'Kategori',
      'passenger_info_label': 'Nama / No. Ponsel Penumpang (Opsional)',
      'incident_desc_label': 'Kronologi Kejadian',
      'incident_desc_hint': 'Jelaskan apa yang terjadi...',
      'btn_submit_report': 'Kirim Laporan',
      'desc_required': 'Deskripsi diperlukan',
      'complaint_received_title': 'Laporan Diterima',
      'complaint_received_msg': 'Tim keamanan akan segera menindaklanjuti.',
      'btn_ok': 'OK',
      'report_safety_title': 'Laporkan Bahaya di Jalan',
      'report_safety_sub': 'Laporkan kecelakaan atau area berbahaya.',
      'report_safety_dialog_title': 'Laporkan Bahaya di Jalan',
      'location_label': 'Lokasi',
      'safety_desc_hint': 'Apa yang terjadi dan bantuan apa yang diperlukan...',
      'btn_submit_safety': 'Kirim ke Tim Tanggap Cepat',
      'safety_received_title': 'Terkirim ke Tim Tanggap Cepat',
      'safety_received_msg': 'Tim akan segera mengevaluasi situasi.',
      'hotlines_title': 'Saluran Bantuan Darurat 24/7',
    },
    'tr': {
      'app_bar_title': 'Güvenlik ve Acil Durum Desteği',
      'tab_sos': 'SOS ve Acil Durum',
      'tab_tracking': 'Yakınlar ve Takip',
      'tab_reports': 'Bildirimler ve Yardım Hatları',
      'sos_active_banner': '🚨 Acil durum sinyali aktif! Komuta merkezi konumunuzu izliyor.',
      'sos_headline': 'Tek Dokunuşla Acil Yardım',
      'sos_subheadline': 'Butona basıldığında canlı GPS konumunuz komuta merkezine ve polise (999) iletilir.',
      'sos_btn_label': 'Tek Dokunuşla SOS',
      'police_title': 'Ulusal Acil Durum Çağrı Merkezi (999)',
      'police_sub': 'Polis, Ambulans ve İtfaiye',
      'call_999_btn': '999\'u Ara',
      'command_title': 'Shadhin Jatra Komuta Masası',
      'command_sub': '7/24 Sürücü Güvenlik Ekibi',
      'command_btn': 'Komuta Odası',
      'sos_dialog_title': 'Acil Durum Sinyali (SOS)',
      'sos_dialog_content': 'Komuta merkezine ve polise (999) acil durum uyarısı gönderilsin mi?',
      'sos_note_hint': 'Acil durum notu (isteğe bağlı)',
      'btn_cancel': 'İptal',
      'btn_send_sos': 'Evet, Gönder',
      'sos_success_title': '🚨 Acil Durum Uyarısı Aktif!',
      'sos_success_msg': 'Uyarı komuta merkezine ulaştı. Polis desteği için 999\'u arayın.',
      'btn_call_999': 'Polis 999\'u Ara',
      'guardian_card_title': 'Acil Durum Kişisi (Yakın)',
      'guardian_empty': 'Yakın bilgisi eklenmemiş. Anlık uyarılar için numara ekleyin.',
      'btn_add_contact': 'Kişi Ekle',
      'guardian_default_name': 'Aile Yakını',
      'btn_alert_guardian': 'Yakına Anlık Uyarı ve Konum Gönder',
      'guardian_modal_title': 'Yakın Bilgileri',
      'guardian_name_label': 'Ad Soyad',
      'guardian_phone_label': 'Cep Telefonu',
      'guardian_relation_label': 'Yakınlık Derecesi',
      'btn_save_contact': 'Kaydet',
      'phone_required': 'Lütfen telefon numarası girin',
      'contact_saved': 'Bilgiler kaydedildi',
      'guardian_alert_title': 'Yakına Uyarı Gönderildi',
      'guardian_alert_msg': 'Canlı takip mesajı hazırlandı.',
      'btn_send_whatsapp_sms': 'SMS / WhatsApp ile Gönder',
      'share_tracking_title': 'Canlı Konum Takibini Paylaş',
      'share_tracking_desc': 'Ailenizle güvenli canlı takip bağlantısı paylaşın.',
      'duration_selector': 'Paylaşım süresini seçin:',
      'hours_suffix': 'saat',
      'link_active': 'Canlı bağlantı aktif',
      'expires_prefix': 'Geçerlilik: ',
      'link_copied': 'Takip bağlantısı panoya kopyalandı!',
      'btn_copy_link': 'Bağlantıyı Kopyala',
      'btn_whatsapp': 'WhatsApp',
      'btn_generate_link': 'Yeni Bağlantı Oluştur',
      'report_passenger_title': 'Yolcuyu Bildir',
      'report_passenger_sub': 'Kaba davranış veya ücret ödememe durumlarını bildirin.',
      'btn_report': 'Bildir',
      'report_passenger_dialog_title': 'Yolcuyu Bildir',
      'category_label': 'Kategori',
      'passenger_info_label': 'Yolcu Adı / Telefonu (İsteğe bağlı)',
      'incident_desc_label': 'Olay Açıklaması',
      'incident_desc_hint': 'Olayın nerede ve nasıl olduğunu açıklayın...',
      'btn_submit_report': 'Şikayeti Gönder',
      'desc_required': 'Açıklama gereklidir',
      'complaint_received_title': 'Şikayet Alındı',
      'complaint_received_msg': 'Güvenlik ekibi durumu inceleyecektir.',
      'btn_ok': 'Tamam',
      'report_safety_title': 'Yol Tehlikesini Bildir',
      'report_safety_sub': 'Trafik kazası veya tehlikeli bölgeleri bildirin.',
      'report_safety_dialog_title': 'Yol Tehlikesini Bildir',
      'location_label': 'Konum',
      'safety_desc_hint': 'Ne oldu ve ne tür yardım gerekiyor...',
      'btn_submit_safety': 'Müdahale Ekibine Gönder',
      'safety_received_title': 'Müdahale Ekibine Gönderildi',
      'safety_received_msg': 'Müdahale ekibi derhal durumu değerlendirecektir.',
      'hotlines_title': '7/24 Acil Yardım Hatları',
    },
    'de': {
      'app_bar_title': 'Sicherheit & Notfallhilfe',
      'tab_sos': 'SOS & Notfall',
      'tab_tracking': 'Kontakt & Tracking',
      'tab_reports': 'Meldungen & Notruf',
      'sos_active_banner': '🚨 Notruf aktiv! Die Einsatzzentrale überwacht Ihren Standort.',
      'sos_headline': '1-Klick-Notfallhilfe',
      'sos_subheadline': 'Ein Klick übermittelt Ihre GPS-Position sofort an die Zentrale und die Polizei (999).',
      'sos_btn_label': '1-Klick-Notrufsignal',
      'police_title': 'Nationaler Notruf (999)',
      'police_sub': 'Polizei, Rettungsdienst und Feuerwehr',
      'call_999_btn': '999 anrufen',
      'command_title': 'Shadhin Jatra Einsatzzentrale',
      'command_sub': 'Rund um die Uhr (24/7) Fahrersicherheit',
      'command_btn': 'Einsatzzentrale',
      'sos_dialog_title': 'Notrufsignal (SOS)',
      'sos_dialog_content': 'Sofortigen Notruf an die Einsatzzentrale und Polizei (999) senden?',
      'sos_note_hint': 'Notfallgrund (optional)',
      'btn_cancel': 'Abbrechen',
      'btn_send_sos': 'Ja, Alarm senden',
      'sos_success_title': '🚨 Notfallalarm aktiv!',
      'sos_success_msg': 'Alarm in der Zentrale eingegangen. Rufen Sie 999 für Polizeihilfe an.',
      'btn_call_999': 'Polizei 999 anrufen',
      'guardian_card_title': 'Notfallkontakt (Angehörige)',
      'guardian_empty': 'Kein Notfallkontakt hinterlegt. Fügen Sie einen Kontakt für Sofortalarmierungen hinzu.',
      'btn_add_contact': 'Kontakt hinzufügen',
      'guardian_default_name': 'Angehöriger',
      'btn_alert_guardian': 'Sofortalarm & Standort an Angehörigen senden',
      'guardian_modal_title': 'Angaben zum Angehörigen',
      'guardian_name_label': 'Name',
      'guardian_phone_label': 'Mobilnummer',
      'guardian_relation_label': 'Verwandtschaftsverhältnis',
      'btn_save_contact': 'Speichern',
      'phone_required': 'Bitte Mobilnummer eingeben',
      'contact_saved': 'Kontakt erfolgreich gespeichert',
      'guardian_alert_title': 'Alarm an Angehörigen gesendet',
      'guardian_alert_msg': 'Live-Standort-Nachricht vorbereitet.',
      'btn_send_whatsapp_sms': 'Per SMS / WhatsApp senden',
      'share_tracking_title': 'Live-Standort teilen',
      'share_tracking_desc': 'Teilen Sie einen sicheren Tracking-Link zur Routenüberwachung.',
      'duration_selector': 'Dauer wählen:',
      'hours_suffix': 'Stunden',
      'link_active': 'Live-Link aktiv',
      'expires_prefix': 'Gültig bis: ',
      'link_copied': 'Tracking-Link in Zwischenablage kopiert!',
      'btn_copy_link': 'Link kopieren',
      'btn_whatsapp': 'WhatsApp',
      'btn_generate_link': 'Neuen Tracking-Link erstellen',
      'report_passenger_title': 'Fahrgast melden',
      'report_passenger_sub': 'Melden Sie Fehlverhalten oder Zahlungsverweigerung.',
      'btn_report': 'Melden',
      'report_passenger_dialog_title': 'Fahrgast melden',
      'category_label': 'Kategorie',
      'passenger_info_label': 'Name / Telefon des Fahrgasts (Optional)',
      'incident_desc_label': 'Vorfallbeschreibung',
      'incident_desc_hint': 'Beschreiben Sie, wo und was vorgefallen ist...',
      'btn_submit_report': 'Meldung einreichen',
      'desc_required': 'Beschreibung erforderlich',
      'complaint_received_title': 'Meldung eingegangen',
      'complaint_received_msg': 'Das Sicherheitsteam wird den Vorfall umgehend prüfen.',
      'btn_ok': 'OK',
      'report_safety_title': 'Gefahr melden',
      'report_safety_sub': 'Melden Sie Unfälle, Pannen oder Gefahrenzonen.',
      'report_safety_dialog_title': 'Gefahr melden',
      'location_label': 'Standort',
      'safety_desc_hint': 'Was ist passiert und welche Hilfe wird benötigt...',
      'btn_submit_safety': 'An Einsatzteam senden',
      'safety_received_title': 'An Einsatzteam übermittelt',
      'safety_received_msg': 'Das Einsatzteam prüft die Lage umgehend.',
      'hotlines_title': '24/7 Notrufnummern & Hotlines',
    },
  };

  static String get(String key, {required String langCode}) {
    return _values[langCode]?[key] ?? _values['en']?[key] ?? key;
  }
}

class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({super.key});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isLoading = true;
  bool _isSendingSos = false;
  bool _isAlertingGuardian = false;
  bool _isSharingLocation = false;
  bool _isSosActive = false;

  Map<String, dynamic>? _sosData;
  Map<String, dynamic>? _guardianContact;
  List<dynamic> _hotlines = [];
  Map<String, dynamic>? _liveLocationShare;

  String get _currentLangCode {
    try {
      final code = context.locale.languageCode;
      if (code.isNotEmpty) return code;
    } catch (_) {}
    return 'en';
  }

  String _t(String key) {
    return _SosLocalization.get(key, langCode: _currentLangCode);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadSafetyData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSafetyData() async {
    setState(() => _isLoading = true);
    try {
      final hotlinesRes = await AuthService.fetchDriverSafetyHotlines();
      if (hotlinesRes['success'] == true && hotlinesRes['data'] != null) {
        _hotlines = hotlinesRes['data']['hotlines'] ?? [];
        _sosData = hotlinesRes['data']['safety_support'];
      }

      final contactRes = await AuthService.fetchDriverEmergencyContact();
      if (contactRes['success'] == true && contactRes['data'] != null) {
        _guardianContact = contactRes['data'];
      }
    } catch (e) {
      debugPrint('Error loading safety data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('Location fetch error: $e');
      return null;
    }
  }

  // ==========================================
  // 1. SOS EMERGENCY TRIGGER
  // ==========================================
  Future<void> _triggerSosAlert() async {
    final noteController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _t('sos_dialog_title'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('sos_dialog_content'),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: _t('sos_note_hint'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('btn_cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            icon: const Icon(Icons.emergency),
            label: Text(_t('btn_send_sos')),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSendingSos = true);
    final pos = await _getCurrentLocation();

    final res = await AuthService.triggerDriverSos(
      lat: pos?.latitude,
      lng: pos?.longitude,
      details: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
    );

    if (mounted) {
      setState(() {
        _isSendingSos = false;
        if (res['success'] == true) _isSosActive = true;
      });

      _showSuccessDialog(
        title: _t('sos_success_title'),
        message: res['message'] ?? _t('sos_success_msg'),
        actionText: _t('btn_call_999'),
        onAction: () => launchUrl(Uri.parse('tel:999')),
      );
    }
  }

  // ==========================================
  // 2. EMERGENCY CONTACT (GUARDIAN)
  // ==========================================
  void _showEditContactModal() {
    final nameCtrl = TextEditingController(text: _guardianContact?['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: _guardianContact?['phone']?.toString() ?? '');
    String relation = _guardianContact?['relation']?.toString() ?? 'Father';

    final relations = ['Father', 'Mother', 'Spouse', 'Brother', 'Sister', 'Friend', 'Guardian'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_t('guardian_modal_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: _t('guardian_name_label'),
                  prefixIcon: const Icon(Icons.person, color: Colors.blue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: _t('guardian_phone_label'),
                  prefixIcon: const Icon(Icons.phone, color: Colors.green),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: relations.contains(relation) ? relation : 'Guardian',
                decoration: InputDecoration(
                  labelText: _t('guardian_relation_label'),
                  prefixIcon: const Icon(Icons.family_restroom, color: Colors.orange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => relation = val);
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                  onPressed: () async {
                    final phone = phoneCtrl.text.trim();
                    if (phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_t('phone_required'))),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    final res = await AuthService.updateDriverEmergencyContact(
                      phone: phone,
                      name: nameCtrl.text.trim(),
                      relation: relation,
                    );

                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                        if (res['success'] == true) {
                          _guardianContact = res['data'];
                        }
                      });

                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                          content: Text(res['message'] ?? _t('contact_saved')),
                        ),
                      );
                    }
                  },
                  child: Text(_t('btn_save_contact'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _alertGuardian() async {
    final phone = _guardianContact?['phone']?.toString();
    if (phone == null || phone.isEmpty) {
      _showEditContactModal();
      return;
    }

    setState(() => _isAlertingGuardian = true);
    final pos = await _getCurrentLocation();

    final res = await AuthService.alertDriverEmergencyContact(
      lat: pos?.latitude,
      lng: pos?.longitude,
    );

    if (mounted) {
      setState(() => _isAlertingGuardian = false);
      final alertMsg = res['data']?['alert_message'] ?? '';
      _showSuccessDialog(
        title: _t('guardian_alert_title'),
        message: res['message'] ?? _t('guardian_alert_msg'),
        actionText: _t('btn_send_whatsapp_sms'),
        onAction: () async {
          final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(alertMsg)}');
          if (await canLaunchUrl(uri)) launchUrl(uri);
        },
      );
    }
  }

  // ==========================================
  // 3. SHARE LIVE LOCATION
  // ==========================================
  Future<void> _generateLiveShareLink(int hours) async {
    setState(() => _isSharingLocation = true);
    final pos = await _getCurrentLocation();

    final res = await AuthService.shareDriverLiveLocation(
      lat: pos?.latitude,
      lng: pos?.longitude,
      durationHours: hours,
      sharedVia: 'link',
    );

    if (mounted) {
      setState(() {
        _isSharingLocation = false;
        if (res['success'] == true) {
          _liveLocationShare = res['data'];
        }
      });

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.green, content: Text(_t('link_active'))),
        );
      }
    }
  }

  // ==========================================
  // 4. REPORT PASSENGER MODAL
  // ==========================================
  void _showReportPassengerModal() {
    final passengerCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final isBn = _currentLangCode == 'bn';
    final isAr = _currentLangCode == 'ar';

    final categories = isBn
        ? [
            'অসদাচরণ ও আক্রমণাত্মক আচরণ (Misbehavior)',
            'ভাড়া প্রদানে অস্বীকৃতি (Refused to Pay)',
            'মদ্যপ বা উচ্ছৃঙ্খল অবস্থা (Drunk / Aggressive)',
            'ভুয়া বুকিং / বিভ্রান্তিকর ড্রপ (Fake Booking)',
            'যানবাহনের ক্ষতিসাধন (Vehicle Damage)',
            'শারীরিক হুমকি বা হেনস্থা (Threat / Harassment)',
            'অন্যান্য সমস্যা (Other Complaint)',
          ]
        : isAr
            ? [
                'سوء سلوك أو تصرفات عدوانية (Misbehavior)',
                'رفض دفع الأجرة (Refused to Pay)',
                'حالة سكر أو فوضى (Drunk / Aggressive)',
                'حجز وهمي (Fake Booking)',
                'إلحاق ضرر بالمركبة (Vehicle Damage)',
                'تهديد أو تحرش (Threat / Harassment)',
                'شكاوى أخرى (Other Complaint)',
              ]
            : [
                'Misbehavior & Verbal Abuse',
                'Refused to Pay Fare',
                'Drunk or Aggressive Behavior',
                'Fake Booking / False Pickup',
                'Vehicle Damage or Littering',
                'Threat, Safety Violation or Harassment',
                'Other Complaint',
              ];

    String category = categories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_off_rounded, color: Colors.red, size: 24),
                  const SizedBox(width: 8),
                  Text(_t('report_passenger_dialog_title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _t('category_label'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => category = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passengerCtrl,
                decoration: InputDecoration(
                  labelText: _t('passenger_info_label'),
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _t('incident_desc_label'),
                  hintText: _t('incident_desc_hint'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                  icon: const Icon(Icons.send_rounded),
                  label: Text(_t('btn_submit_report'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final desc = noteCtrl.text.trim();
                    if (desc.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_t('desc_required'))),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    final pos = await _getCurrentLocation();

                    final res = await AuthService.reportPassenger(
                      category: category,
                      description: desc,
                      location: 'Dhaka',
                      lat: pos?.latitude,
                      lng: pos?.longitude,
                    );

                    if (mounted) {
                      setState(() => _isLoading = false);
                      _showSuccessDialog(
                        title: _t('complaint_received_title'),
                        message: res['message'] ?? _t('complaint_received_msg'),
                        actionText: _t('btn_ok'),
                        onAction: () => Navigator.pop(context),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 5. REPORT SAFETY ISSUE MODAL
  // ==========================================
  void _showReportSafetyIssueModal() {
    final locationCtrl = TextEditingController(text: 'Dhaka Metro Area');
    final noteCtrl = TextEditingController();
    final isBn = _currentLangCode == 'bn';
    final isAr = _currentLangCode == 'ar';

    final categories = isBn
        ? [
            'সড়ক দুর্ঘটনা / সংঘর্ষ (Road Accident)',
            'যানবাহন যান্ত্রিক ত্রুটি / ব্রেকডাউন (Vehicle Breakdown)',
            'ছিনতাই বা অনিরাপদ এলাকা ঝুঁকি (Robbery / Hazard Area)',
            'শারীরিক অসুস্থতা / তাৎক্ষণিক অ্যাম্বুলেন্স (Medical Emergency)',
            'রাস্তা অবরোধ / দুর্যোগ / যানজট (Road Block / Waterlogging)',
            'অন্যান্য নিরাপত্তা ঝুঁকি (Other Safety Risk)',
          ]
        : isAr
            ? [
                'حادث مروري أو تصادم (Road Accident)',
                'عطل فني في المركبة (Vehicle Breakdown)',
                'منطقة خطرة أو تعرض للسرقة (Robbery / Hazard)',
                'حالة طبية طارئة / إسعاف (Medical Emergency)',
                'قطع طريق / تقلبات جوية (Road Block)',
                'مخاطر أمنية أخرى (Other Safety Risk)',
              ]
            : [
                'Road Accident / Collision',
                'Vehicle Breakdown / Mechanical Failure',
                'Robbery / Hazardous Incident Area',
                'Medical Emergency / Immediate Ambulance',
                'Road Block / Weather Hazard',
                'Other Safety Issue',
              ];

    String category = categories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.health_and_safety_rounded, color: Colors.orange, size: 24),
                  const SizedBox(width: 8),
                  Text(_t('report_safety_dialog_title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _t('category_label'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => category = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: InputDecoration(
                  labelText: _t('location_label'),
                  prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _t('incident_desc_label'),
                  hintText: _t('safety_desc_hint'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C), foregroundColor: Colors.white),
                  icon: const Icon(Icons.notification_important_rounded),
                  label: Text(_t('btn_submit_safety'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final desc = noteCtrl.text.trim();
                    if (desc.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_t('desc_required'))),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    final pos = await _getCurrentLocation();

                    final res = await AuthService.reportSafetyIssue(
                      category: category,
                      description: desc,
                      location: locationCtrl.text.trim(),
                      lat: pos?.latitude,
                      lng: pos?.longitude,
                    );

                    if (mounted) {
                      setState(() => _isLoading = false);
                      _showSuccessDialog(
                        title: _t('safety_received_title'),
                        message: res['message'] ?? _t('safety_received_msg'),
                        actionText: _t('btn_ok'),
                        onAction: () => Navigator.pop(context),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog({
    required String title,
    required String message,
    required String actionText,
    required VoidCallback onAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              onAction();
            },
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = _currentLangCode;
    final isRtl = lang == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(_t('app_bar_title')),
          backgroundColor: const Color(0xFFDC2626),
          foregroundColor: Colors.white,
          elevation: 1,
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: const Icon(Icons.emergency_rounded, size: 20), text: _t('tab_sos')),
              Tab(icon: const Icon(Icons.share_location_rounded, size: 20), text: _t('tab_tracking')),
              Tab(icon: const Icon(Icons.report_problem_rounded, size: 20), text: _t('tab_reports')),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626)))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildSosTab(),
                  _buildContactAndTrackingTab(),
                  _buildReportsAndHotlinesTab(),
                ],
              ),
      ),
    );
  }

  // ==========================================
  // TAB 1: SOS EMERGENCY & ACTION
  // ==========================================
  Widget _buildSosTab() {
    return RefreshIndicator(
      onRefresh: _loadSafetyData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isSosActive)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _t('sos_active_banner'),
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() => _isSosActive = false),
                  ),
                ],
              ),
            ),

          Text(
            _t('sos_headline'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            _t('sos_subheadline'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 36),

          // Pulsing SOS Button
          Center(
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: GestureDetector(
                onTap: _isSendingSos ? null : _triggerSosAlert,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.45),
                        spreadRadius: 10,
                        blurRadius: 25,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSendingSos
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shield_rounded, color: Colors.white, size: 38),
                              const SizedBox(height: 4),
                              const Text(
                                'SOS',
                                style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2),
                              ),
                              Text(
                                _t('sos_btn_label'),
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Instant Call 999 Action Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: const Icon(Icons.local_police_rounded, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_t('police_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(_t('police_sub'), style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                      icon: const Icon(Icons.call, size: 16),
                      label: Text(_t('call_999_btn')),
                      onPressed: () => launchUrl(Uri.parse('tel:999')),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.teal.shade50,
                      child: const Icon(Icons.headset_mic_rounded, color: Colors.teal),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_t('command_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(_t('command_sub'), style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      icon: const Icon(Icons.phone_in_talk, size: 16),
                      label: Text(_t('command_btn')),
                      onPressed: () {
                        final helpline = _sosData?['helpline'] ?? '+8801900000000';
                        launchUrl(Uri.parse('tel:$helpline'));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: GUARDIAN CONTACT & SHARE LIVE LOCATION
  // ==========================================
  Widget _buildContactAndTrackingTab() {
    final contactName = _guardianContact?['name'] ?? '';
    final contactPhone = _guardianContact?['phone'] ?? '';
    final contactRelation = _guardianContact?['relation'] ?? 'Guardian';
    final hasContact = contactPhone.toString().isNotEmpty;

    final shareUrl = _liveLocationShare?['tracking_url'] ?? '';
    final expiryTime = _liveLocationShare?['expires_at'] ?? '';
    final whatsappMsg = _liveLocationShare?['whatsapp_message'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 2. Emergency Contact Section
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.family_restroom_rounded, color: Color(0xFF1E3A8A), size: 22),
                        const SizedBox(width: 8),
                        Text(_t('guardian_card_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF1E3A8A)),
                      onPressed: _showEditContactModal,
                      tooltip: 'Edit',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!hasContact)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amber),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _t('guardian_empty'),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: _showEditContactModal,
                          child: Text(_t('btn_add_contact'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(Icons.person, color: Color(0xFF1E3A8A)),
                        ),
                        title: Text(contactName.isNotEmpty ? contactName : _t('guardian_default_name'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$contactPhone ($contactRelation)', style: const TextStyle(color: Colors.black54)),
                        trailing: IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () => launchUrl(Uri.parse('tel:$contactPhone')),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                          icon: _isAlertingGuardian
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.warning_amber_rounded, size: 18),
                          label: Text(_t('btn_alert_guardian')),
                          onPressed: _isAlertingGuardian ? null : _alertGuardian,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 3. Share Live Location Section
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.share_location_rounded, color: Color(0xFF059669), size: 22),
                    const SizedBox(width: 8),
                    Text(_t('share_tracking_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _t('share_tracking_desc'),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 16),

                // Duration Selector
                Text(_t('duration_selector'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [1, 3, 6, 12].map((hours) {
                    return OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: _isSharingLocation ? null : () => _generateLiveShareLink(hours),
                      child: Text('$hours ${_t('hours_suffix')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                if (_liveLocationShare != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                            const SizedBox(width: 6),
                            Text(_t('link_active'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            const Spacer(),
                            Text('${_t('expires_prefix')}$expiryTime', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          shareUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.blueAccent, decoration: TextDecoration.underline),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.copy, size: 16),
                                label: Text(_t('btn_copy_link')),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: shareUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(_t('link_copied'))),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                label: Text(_t('btn_whatsapp')),
                                onPressed: () async {
                                  final waUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(whatsappMsg.isNotEmpty ? whatsappMsg : shareUrl)}');
                                  if (await canLaunchUrl(waUri)) launchUrl(waUri, mode: LaunchMode.externalApplication);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                      icon: _isSharingLocation
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.share, size: 18),
                      label: Text(_t('btn_generate_link')),
                      onPressed: _isSharingLocation ? null : () => _generateLiveShareLink(3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: REPORTS & 24/7 HOTLINES
  // ==========================================
  Widget _buildReportsAndHotlinesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 4. Report Passenger Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Colors.red.shade50,
              radius: 24,
              child: const Icon(Icons.person_off_rounded, color: Colors.red),
            ),
            title: Text(_t('report_passenger_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text(_t('report_passenger_sub'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
              onPressed: _showReportPassengerModal,
              child: Text(_t('btn_report')),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 5. Report Safety Issue Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade50,
              radius: 24,
              child: const Icon(Icons.health_and_safety_rounded, color: Colors.orange),
            ),
            title: Text(_t('report_safety_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text(_t('report_safety_sub'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
              onPressed: _showReportSafetyIssueModal,
              child: Text(_t('btn_report')),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 6. Emergency Support & Hotlines Section
        Text(_t('hotlines_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        ..._hotlines.map((h) {
          final isBn = _currentLangCode == 'bn';
          final name = (isBn ? h['name_bn'] : h['name_en']) ?? h['name_bn'] ?? h['name_en'] ?? 'Helpline';
          final number = h['number'] ?? '999';
          final type = h['type'] ?? 'police';

          IconData icon = Icons.phone;
          Color color = Colors.blue;
          if (type == 'police') {
            icon = Icons.local_police;
            color = const Color(0xFF1E3A8A);
          } else if (type == 'ambulance') {
            icon = Icons.medical_services;
            color = Colors.red;
          } else if (type == 'fire') {
            icon = Icons.fire_truck;
            color = Colors.deepOrange;
          } else if (type == 'women_helpline') {
            icon = Icons.support_agent;
            color = Colors.purple;
          } else if (type == 'platform_support') {
            icon = Icons.headset_mic;
            color = Colors.teal;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(number, style: const TextStyle(color: Colors.black54, fontSize: 13)),
              trailing: IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () => launchUrl(Uri.parse('tel:$number')),
              ),
            ),
          );
        }),
      ],
    );
  }
}
