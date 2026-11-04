// import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // ✅ TAMBAHKAN BARIS INI (Untuk DateFormat)

import '../models/order_model.dart';
import '../models/reservation_model.dart';

class EmailService {
  // static final String _apiKey = dotenv.env['RESEND_API_KEY'] ?? '';

  // ⚠️ Untuk testing, gunakan 'onboarding@resend.dev'
  // Nanti ganti dengan email domain Anda setelah verifikasi domain
  static const String _fromEmail = 'The Mulia Bali <onboarding@resend.dev>';

  /// ✅ METHOD BARU: Kirim Email via Supabase Edge Function (Aman untuk PWA & Bebas CORS)
  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String htmlContent,
  }) async {
    try {
      print('📧 [EMAIL] Memanggil Edge Function untuk mengirim email ke: $to');

      final response = await Supabase.instance.client.functions.invoke(
        'send-email', // Nama Edge Function Anda
        body: {
          'from': _fromEmail,
          'to': to,
          'subject': subject,
          'html': htmlContent,
        },
      );

      if (response.status == 200) {
        print('✅ [EMAIL] Email berhasil dikirim via Edge Function!');
        return true;
      } else {
        print('❌ [EMAIL] Gagal mengirim email. Status: ${response.status}');
        print('❌ [EMAIL] Detail Error: ${response.data}');
        return false;
      }
    } catch (e) {
      print('❌ [EMAIL] Error saat memanggil Edge Function: $e');
      return false;
    }
  }

  /// ✅ TEMPLATE: Booking Confirmation (Saat Checkout)
  static String generateConfirmationTemplate(Order order, String guestName) {
    String itemsHtml = order.items
        .map((item) {
          String meta = '';
          if (item.metadata['date'] != null)
            meta += '📅 ${item.metadata['date']} ';
          if (item.metadata['time'] != null)
            meta += '• 🕐 ${item.metadata['time']} ';

          return '''
        <tr>
          <td style="padding: 12px 0; border-bottom: 1px solid #eee;">
            <div style="font-weight: bold; color: #333;">${item.itemName}</div>
            <div style="font-size: 13px; color: #666; margin-top: 4px;">$meta</div>
          </td>
          <td style="padding: 12px 0; border-bottom: 1px solid #eee; text-align: right; font-weight: bold; color: #333;">
            IDR ${_formatCurrency(item.totalPrice)}
          </td>
        </tr>
      ''';
        })
        .join('');

    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: 'Helvetica Neue', Arial, sans-serif; background-color: #f9f9f9; padding: 20px; }
          .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
          .header { background-color: #2C2C2C; color: #D4AF37; padding: 30px; text-align: center; }
          .header h1 { margin: 0; font-family: 'Georgia', serif; font-size: 28px; }
          .content { padding: 30px; color: #333; }
          .order-number { background: #f0f0f0; padding: 15px; border-radius: 8px; text-align: center; margin-bottom: 20px; }
          .order-number span { font-size: 20px; font-weight: bold; color: #2C2C2C; }
          .footer { background-color: #f4f4f4; padding: 20px; text-align: center; font-size: 12px; color: #666; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>The Mulia Bali</h1>
            <p style="margin: 10px 0 0; color: #fff; font-size: 14px;">Booking Received</p>
          </div>
          <div class="content">
            <p>Dear <strong>$guestName</strong>,</p>
            <p>Thank you for choosing The Mulia Bali. We have received your booking request and our team is currently reviewing it.</p>
            
            <div class="order-number">
              <div style="font-size: 12px; color: #666; margin-bottom: 5px;">ORDER NUMBER</div>
              <span>${order.orderNumber}</span>
            </div>

            <h3 style="border-bottom: 2px solid #D4AF37; padding-bottom: 8px; display: inline-block;">Booking Details</h3>
            <table style="width: 100%; border-collapse: collapse; margin-top: 10px;">
              $itemsHtml
              <tr>
                <td style="padding-top: 20px; font-weight: bold; font-size: 16px;">TOTAL AMOUNT</td>
                <td style="padding-top: 20px; text-align: right; font-weight: bold; font-size: 18px; color: #D4AF37;">
                  IDR ${_formatCurrency(order.totalAmount)}
                </td>
              </tr>
            </table>

            <p style="margin-top: 30px; font-size: 14px; color: #666;">
              You will receive another email once your booking is <strong>Confirmed</strong> by our team. 
              You can also check your booking status anytime in the "My Bookings" section of our app.
            </p>
            
            <p>Warm regards,<br><strong>The Mulia Bali Concierge Team</strong></p>
          </div>
          <div class="footer">
            <p>© 2026 The Mulia Bali. All rights reserved.<br>Jl. Raya Nusa Dua Selatan, Bali, Indonesia</p>
          </div>
        </div>
      </body>
      </html>
    ''';
  }

  /// ✅ TEMPLATE: Booking Status Update (Confirmed / Cancelled / Completed)
  static String xxxgenerateStatusUpdateTemplate(
    Order order,
    String guestName,
    String newStatus,
  ) {
    String statusColor = newStatus == 'confirmed'
        ? '#28a745'
        : (newStatus == 'cancelled' ? '#dc3545' : '#007bff');
    String statusMessage = newStatus == 'confirmed'
        ? 'Great news! Your booking has been officially confirmed by our team.'
        : (newStatus == 'cancelled'
              ? 'Your booking has been cancelled as requested.'
              : 'Thank you for experiencing our services. We hope to welcome you back soon.');

    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: 'Helvetica Neue', Arial, sans-serif; background-color: #f9f9f9; padding: 20px; }
          .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
          .header { background-color: #2C2C2C; color: #D4AF37; padding: 30px; text-align: center; }
          .content { padding: 30px; color: #333; text-align: center; }
          .status-badge { display: inline-block; padding: 10px 20px; background-color: $statusColor; color: white; border-radius: 20px; font-weight: bold; font-size: 18px; margin: 20px 0; text-transform: uppercase; }
          .footer { background-color: #f4f4f4; padding: 20px; text-align: center; font-size: 12px; color: #666; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1 style="margin: 0; font-family: 'Georgia', serif;">The Mulia Bali</h1>
          </div>
          <div class="content">
            <p>Dear <strong>$guestName</strong>,</p>
            <p>$statusMessage</p>
            
            <div class="status-badge">
              ${newStatus.toUpperCase()}
            </div>

            <p style="font-size: 14px; color: #666;">
              <strong>Order Number:</strong> ${order.orderNumber}<br>
              <strong>Total Amount:</strong> IDR ${_formatCurrency(order.totalAmount)}
            </p>

            <p style="margin-top: 30px;">Warm regards,<br><strong>The Mulia Bali Concierge Team</strong></p>
          </div>
          <div class="footer">
            <p>© 2026 The Mulia Bali. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    ''';
  }

  /// ✅ TEMPLATE BARU: Reservasi Kamar (Saat Booking Berhasil)
  static String generateReservationConfirmationTemplate(
    Reservation res,
    String guestName,
  ) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: 'Helvetica Neue', Arial, sans-serif; background-color: #f9f9f9; padding: 20px; }
          .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
          .header { background-color: #2C2C2C; color: #D4AF37; padding: 30px; text-align: center; }
          .header h1 { margin: 0; font-family: 'Georgia', serif; font-size: 28px; }
          .content { padding: 30px; color: #333; }
          .res-number { background: #f0f0f0; padding: 15px; border-radius: 8px; text-align: center; margin-bottom: 20px; }
          .res-number span { font-size: 20px; font-weight: bold; color: #2C2C2C; }
          .detail-row { display: flex; justify-content: space-between; margin-bottom: 12px; border-bottom: 1px solid #eee; padding-bottom: 8px; }
          .footer { background-color: #f4f4f4; padding: 20px; text-align: center; font-size: 12px; color: #666; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>The Mulia Bali</h1>
            <p style="margin: 10px 0 0; color: #fff; font-size: 14px;">Room Reservation Received</p>
          </div>
          <div class="content">
            <p>Dear <strong>$guestName</strong>,</p>
            <p>Thank you for choosing to stay with us. We have received your room reservation request.</p>
            
            <div class="res-number">
              <div style="font-size: 12px; color: #666; margin-bottom: 5px;">RESERVATION NUMBER</div>
              <span>${res.reservationNumber}</span>
            </div>

            <h3 style="border-bottom: 2px solid #D4AF37; padding-bottom: 8px; display: inline-block;">Stay Details</h3>
            
            <div class="detail-row">
              <span style="color: #666;">Room Type</span>
              <strong>${res.roomName ?? 'Standard Room'}</strong>
            </div>
            <div class="detail-row">
              <span style="color: #666;">Check-in</span>
              <strong>${DateFormat('dd MMM yyyy').format(res.checkIn)}</strong>
            </div>
            <div class="detail-row">
              <span style="color: #666;">Check-out</span>
              <strong>${DateFormat('dd MMM yyyy').format(res.checkOut)}</strong>
            </div>
            <div class="detail-row">
              <span style="color: #666;">Duration</span>
              <strong>${res.nights} Night${res.nights > 1 ? 's' : ''}</strong>
            </div>
            <div class="detail-row" style="border-bottom: none; margin-top: 20px;">
              <span style="font-size: 16px; font-weight: bold;">TOTAL AMOUNT</span>
              <strong style="font-size: 18px; color: #D4AF37;">IDR ${_formatCurrency(res.totalAmount)}</strong>
            </div>

            <p style="margin-top: 30px; font-size: 14px; color: #666;">
              Our team will review your reservation and send you a confirmation email shortly.
            </p>
            
            <p>Warm regards,<br><strong>The Mulia Bali Concierge Team</strong></p>
          </div>
          <div class="footer">
            <p>© 2026 The Mulia Bali. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    ''';
  }

  /// ✅ TEMPLATE BARU: Update Status Reservasi (Confirmed / Cancelled / Checked-in)
  static String generateReservationStatusTemplate(
    Reservation res,
    String guestName,
    String newStatus,
  ) {
    String statusColor = newStatus == 'confirmed'
        ? '#28a745'
        : (newStatus == 'cancelled' ? '#dc3545' : '#007bff');
    String statusMessage = newStatus == 'confirmed'
        ? 'Great news! Your room reservation has been officially confirmed.'
        : (newStatus == 'cancelled'
              ? 'Your room reservation has been cancelled as requested.'
              : 'Your stay status has been updated to $newStatus.');

    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: 'Helvetica Neue', Arial, sans-serif; background-color: #f9f9f9; padding: 20px; }
          .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
          .header { background-color: #2C2C2C; color: #D4AF37; padding: 30px; text-align: center; }
          .content { padding: 30px; color: #333; text-align: center; }
          .status-badge { display: inline-block; padding: 10px 20px; background-color: $statusColor; color: white; border-radius: 20px; font-weight: bold; font-size: 18px; margin: 20px 0; text-transform: uppercase; }
          .footer { background-color: #f4f4f4; padding: 20px; text-align: center; font-size: 12px; color: #666; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1 style="margin: 0; font-family: 'Georgia', serif;">The Mulia Bali</h1>
          </div>
          <div class="content">
            <p>Dear <strong>$guestName</strong>,</p>
            <p>$statusMessage</p>
            
            <div class="status-badge">${newStatus.toUpperCase()}</div>

            <p style="font-size: 14px; color: #666;">
              <strong>Reservation Number:</strong> ${res.reservationNumber}<br>
              <strong>Room:</strong> ${res.roomName ?? 'Standard Room'}<br>
              <strong>Check-in:</strong> ${DateFormat('dd MMM yyyy').format(res.checkIn)}
            </p>

            <p style="margin-top: 30px;">Warm regards,<br><strong>The Mulia Bali Concierge Team</strong></p>
          </div>
          <div class="footer">
            <p>© 2026 The Mulia Bali. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    ''';
  }

  /// ✅ TEMPLATE UNIVERSAL: Status Update untuk Order (Services) & Reservation (Accommodation)
  static String generateStatusUpdateTemplate(
    dynamic booking, // Bisa menerima Order atau Reservation
    String guestName,
    String newStatus, {
    String? rejectionReason, // ✅ BARU: Agar user tahu alasan revisi via email
  }) {
    // 1. Tentukan warna dan pesan berdasarkan status
    String statusColor = '#007bff'; // Default (Pending/Revision)
    String statusMessage = '';

    if (newStatus == 'confirmed') {
      statusColor = '#28a745'; // Hijau
      statusMessage = booking is Order
          ? 'Great news! Your service booking has been officially confirmed by our team.'
          : 'Great news! Your room reservation has been officially confirmed.';
    } else if (newStatus == 'cancelled') {
      statusColor = '#dc3545'; // Merah
      statusMessage = 'Your booking has been cancelled as requested.';
    } else if (newStatus == 'pending') {
      statusColor = '#fd7e14'; // Orange (Untuk Revisi)
      statusMessage = 'Our team has reviewed your payment proof and requires a revision. Please check the admin note below and re-upload your proof.';
    } else if (newStatus == 'completed') {
      statusColor = '#28a745';
      statusMessage = 'Thank you for experiencing our services. We hope to welcome you back soon!';
    }

    // 2. Ambil data spesifik berdasarkan tipe objek
    String detailsHtml = '';

    if (booking is Order) {
      detailsHtml =
          '''
        <p style="font-size: 14px; color: #666; line-height: 1.6;">
          <strong>Order Number:</strong> ${booking.orderNumber}<br>
          <strong>Total Amount:</strong> IDR ${_formatCurrency(booking.totalAmount)}
        </p>
      ''';
    } else if (booking is Reservation) {
      detailsHtml =
          '''
        <p style="font-size: 14px; color: #666; line-height: 1.6;">
          <strong>Reservation Number:</strong> ${booking.reservationNumber}<br>
          <strong>Room:</strong> ${booking.roomName ?? 'Standard Room'}<br>
          <strong>Check-in:</strong> ${DateFormat('dd MMM yyyy').format(booking.checkIn)}
        </p>
      ''';
    }

    // 3. Tambahkan kotak alasan revisi jika ada
    String rejectionHtml = '';
    if (rejectionReason != null && rejectionReason.isNotEmpty) {
      rejectionHtml =
          '''
        <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; text-align: left; border-radius: 4px;">
          <strong style="color: #856404; display: block; margin-bottom: 5px;">⚠️ Admin Note / Reason for Revision:</strong>
          <span style="color: #856404;">$rejectionReason</span>
        </div>
      ''';
    }

    // 4. Bangun HTML Email
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: 'Helvetica Neue', Arial, sans-serif; background-color: #f9f9f9; padding: 20px; }
          .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
          .header { background-color: #2C2C2C; color: #D4AF37; padding: 30px; text-align: center; }
          .content { padding: 30px; color: #333; text-align: center; }
          .status-badge { display: inline-block; padding: 10px 20px; background-color: $statusColor; color: white; border-radius: 20px; font-weight: bold; font-size: 18px; margin: 20px 0; text-transform: uppercase; }
          .footer { background-color: #f4f4f4; padding: 20px; text-align: center; font-size: 12px; color: #666; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1 style="margin: 0; font-family: 'Georgia', serif;">The Mulia Bali</h1>
          </div>
          <div class="content">
            <p>Dear <strong>$guestName</strong>,</p>
            <p>$statusMessage</p>
            
            <div class="status-badge">${newStatus == 'pending' ? 'REVISION REQUIRED' : newStatus.toUpperCase()}</div>

            $rejectionHtml

            $detailsHtml

            <p style="margin-top: 30px;">Warm regards,<br><strong>The Mulia Bali Concierge Team</strong></p>
          </div>
          <div class="footer">
            <p>© 2026 The Mulia Bali. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    ''';
  }

  /// Helper: Format currency
  static String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
