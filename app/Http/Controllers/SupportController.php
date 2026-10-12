<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class SupportController extends Controller
{
    public function index(Request $request)
    {
        return response()->json([
            'success' => true,
            'data' => [
                'categories' => [
                    ['id' => 'ride', 'title' => 'Ride Issues', 'icon' => 'directions_car'],
                    ['id' => 'payment', 'title' => 'Payment Issues', 'icon' => 'payment'],
                    ['id' => 'account', 'title' => 'Account Issues', 'icon' => 'person'],
                ],
                'faqs' => [
                    ['question' => 'How to cancel a ride?', 'answer' => 'You can cancel a ride from the active ride screen by clicking "Cancel Request" before the driver arrives.'],
                    ['question' => 'How to add a payment method?', 'answer' => 'Go to Wallet > Add Payment Method to add your preferred card or mobile banking.'],
                    ['question' => 'How to contact the driver?', 'answer' => 'Once a ride is accepted, you can call or chat with the driver from the ride tracking screen.'],
                ],
                'contact' => [
                    'phone' => '+8801900000000',
                    'email' => 'support@shadhinjatra.com',
                ]
            ],
            'message' => 'Support data fetched successfully',
        ]);
    }

    public function submitTicket(Request $request)
    {
        $request->validate([
            'category' => 'required|string',
            'subject' => 'required|string|max:255',
            'message' => 'required|string',
        ]);

        // Here we would normally save the ticket to the database
        // Ticket::create([...])

        return response()->json([
            'success' => true,
            'message' => 'Your support ticket has been submitted successfully. We will get back to you soon.',
            'ticket_id' => 'TKT-' . rand(1000, 9999),
        ]);
    }
}
