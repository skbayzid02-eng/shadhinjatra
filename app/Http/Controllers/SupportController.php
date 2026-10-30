<?php

namespace App\Http\Controllers;

use App\Models\Setting;
use App\Models\SupportCategory;
use App\Models\SupportFaq;
use App\Models\SupportTicket;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SupportController extends Controller
{
    /**
     * Get support page data including categories, FAQs, and contact info.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function index(Request $request): JsonResponse
    {
        $categories = SupportCategory::query()
            ->where('is_active', true)
            ->orderBy('order')
            ->get();

        if ($categories->isEmpty()) {
            $categoryList = [
                ['id' => 'ride', 'title' => 'Ride Issues', 'icon' => 'directions_car'],
                ['id' => 'payment', 'title' => 'Payment Issues', 'icon' => 'payment'],
                ['id' => 'account', 'title' => 'Account Issues', 'icon' => 'person'],
            ];
        } else {
            $categoryList = $categories->map(static fn (SupportCategory $cat): array => [
                'id' => (string) ($cat->slug ?: $cat->id),
                'title' => (string) $cat->title,
                'icon' => (string) $cat->icon,
            ])->values()->all();
        }

        $faqs = SupportFaq::query()
            ->where('is_active', true)
            ->orderBy('order')
            ->get();

        if ($faqs->isEmpty()) {
            $faqList = [
                ['question' => 'How to cancel a ride?', 'answer' => 'You can cancel a ride from the active ride screen by clicking "Cancel Request" before the driver arrives.'],
                ['question' => 'How to add a payment method?', 'answer' => 'Go to Wallet > Add Payment Method to add your preferred card or mobile banking.'],
                ['question' => 'How to contact the driver?', 'answer' => 'Once a ride is accepted, you can call or chat with the driver from the ride tracking screen.'],
            ];
        } else {
            $faqList = $faqs->map(static fn (SupportFaq $faq): array => [
                'id' => $faq->id,
                'category_id' => $faq->category_id,
                'question' => (string) $faq->question,
                'answer' => (string) $faq->answer,
            ])->values()->all();
        }

        $phone = (string) (Setting::get('support_phone') ?? Setting::get('contact_phone', '+8801900000000'));
        $email = (string) (Setting::get('support_email') ?? Setting::get('contact_email', 'support@shadhinjatra.com'));

        return response()->json([
            'success' => true,
            'data' => [
                'categories' => $categoryList,
                'faqs' => $faqList,
                'contact' => [
                    'phone' => $phone,
                    'email' => $email,
                ],
            ],
            'message' => 'Support data fetched successfully',
        ]);
    }

    /**
     * Get all active categories with related FAQs from database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function categories(Request $request): JsonResponse
    {
        $categories = SupportCategory::query()
            ->where('is_active', true)
            ->orderBy('order')
            ->with(['faqs' => static function ($query): void {
                $query->where('is_active', true)->orderBy('order');
            }])
            ->get();

        return response()->json([
            'success' => true,
            'data' => $categories,
            'message' => 'Support categories fetched successfully',
        ]);
    }

    /**
     * Collect and store a new support category into the database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function storeCategory(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'slug' => 'required|string|max:100|unique:support_categories,slug',
            'title' => 'required|string|max:255',
            'icon' => 'nullable|string|max:100',
            'order' => 'nullable|integer',
            'is_active' => 'nullable|boolean',
        ]);

        $category = SupportCategory::create([
            'slug' => $validated['slug'],
            'title' => $validated['title'],
            'icon' => $validated['icon'] ?? 'help',
            'order' => $validated['order'] ?? 0,
            'is_active' => $validated['is_active'] ?? true,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Support category created successfully',
            'data' => $category,
        ], 201);
    }

    /**
     * Get all active FAQs from database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function faqs(Request $request): JsonResponse
    {
        $faqs = SupportFaq::query()
            ->where('is_active', true)
            ->orderBy('order')
            ->with('category')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $faqs,
            'message' => 'Support FAQs fetched successfully',
        ]);
    }

    /**
     * Collect and store a new support FAQ into the database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function storeFaq(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'category_id' => 'nullable|exists:support_categories,id',
            'question' => 'required|string|max:500',
            'answer' => 'required|string',
            'order' => 'nullable|integer',
            'is_active' => 'nullable|boolean',
        ]);

        $faq = SupportFaq::create([
            'category_id' => $validated['category_id'] ?? null,
            'question' => $validated['question'],
            'answer' => $validated['answer'],
            'order' => $validated['order'] ?? 0,
            'is_active' => $validated['is_active'] ?? true,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Support FAQ created successfully',
            'data' => $faq,
        ], 201);
    }

    /**
     * Get contact info dynamically from database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function contact(Request $request): JsonResponse
    {
        $phone = (string) (Setting::get('support_phone') ?? Setting::get('contact_phone', '+8801900000000'));
        $email = (string) (Setting::get('support_email') ?? Setting::get('contact_email', 'support@shadhinjatra.com'));

        return response()->json([
            'success' => true,
            'data' => [
                'phone' => $phone,
                'email' => $email,
            ],
            'message' => 'Contact details fetched successfully',
        ]);
    }

    /**
     * Update contact information in database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function updateContact(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'phone' => 'nullable|string|max:50',
            'email' => 'nullable|email|max:100',
        ]);

        if (!empty($validated['phone'])) {
            Setting::set('contact_phone', $validated['phone'], 'contact');
            Setting::set('support_phone', $validated['phone'], 'support');
        }

        if (!empty($validated['email'])) {
            Setting::set('contact_email', $validated['email'], 'contact');
            Setting::set('support_email', $validated['email'], 'support');
        }

        $phone = (string) (Setting::get('support_phone') ?? Setting::get('contact_phone', '+8801900000000'));
        $email = (string) (Setting::get('support_email') ?? Setting::get('contact_email', 'support@shadhinjatra.com'));

        return response()->json([
            'success' => true,
            'message' => 'Contact details updated successfully',
            'data' => [
                'phone' => $phone,
                'email' => $email,
            ],
        ]);
    }

    /**
     * Submit a support ticket and save it to the database.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function submitTicket(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'category' => 'required|string|max:100',
            'subject' => 'required|string|max:255',
            'message' => 'required|string',
        ]);

        $ticketId = 'TKT-' . rand(10000, 99999);

        $ticket = SupportTicket::create([
            'ticket_id' => $ticketId,
            'user_id' => $request->user()?->id,
            'category' => $validated['category'],
            'subject' => $validated['subject'],
            'message' => $validated['message'],
            'status' => 'open',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Your support ticket has been submitted successfully. We will get back to you soon.',
            'ticket_id' => $ticket->ticket_id,
            'data' => $ticket,
        ]);
    }
}
