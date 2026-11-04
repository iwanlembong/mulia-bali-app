import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/reservation_model.dart';
import '../models/order_model.dart'; // ✅ TAMBAHKAN INI

class PdfService {
  // Helper untuk format harga IDR
  static String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  static Future<void> generateReservationInvoice(Reservation res) async {
    final pdf = pw.Document();

    // Hitung ulang subtotal untuk invoice
    final int discount = res.discountAmount ?? 0;
    final int voucherDiscount = res.voucherDiscountAmount ?? 0;
    final int subtotal = res.totalAmount + discount + voucherDiscount;
    final int nights = res.checkOut.difference(res.checkIn).inDays;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // 1. HEADER
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'The Mulia Bali',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.amber,
                        ),
                      ),
                      pw.Text(
                        'Luxury Hospitality',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            // 2. INFO TAMU & RESERVASI
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BILLED TO',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                          letterSpacing: 1,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        res.guestName ?? 'Valued Guest',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        res.guestEmail ?? '-',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'RESERVATION DETAILS',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                          letterSpacing: 1,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'No: ${res.reservationNumber}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Date: ${DateTime.now().toString().split(' ')[0]}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // 3. TABEL DETAIL MENGINAP
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _tableHeader('Room Type'),
                    _tableHeader('Duration'),
                    _tableHeader('Guests'),
                    _tableHeader('Rooms'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _tableCell(res.roomName ?? '-'),
                    _tableCell('$nights Night(s)'),
                    _tableCell(
                      '${res.adults} Adults, ${res.children} Children',
                    ),
                    _tableCell('${res.roomCount} Room(s)'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // 4. RINCIAN HARGA (KANAN)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 300,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _priceRow(
                      'Subtotal (${res.pricePerNight} x $nights nights x ${res.roomCount} rooms)',
                      subtotal,
                    ),
                    if (discount > 0)
                      _priceRow(
                        'Promo Discount (${res.promoCode ?? '-'})',
                        -discount,
                        color: PdfColors.green,
                      ),
                    if (voucherDiscount > 0)
                      _priceRow(
                        'Voucher Loyalty Discount',
                        -voucherDiscount,
                        color: PdfColors.purple700,
                      ),
                    pw.Divider(thickness: 1),
                    pw.SizedBox(height: 8),
                    _priceRow(
                      'TOTAL AMOUNT',
                      res.totalAmount,
                      isBold: true,
                      fontSize: 16,
                      color: PdfColors.amber,
                    ),
                  ],
                ),
              ),
            ),
            pw.Spacer(),

            // 5. FOOTER
            pw.Center(
              child: pw.Text(
                'Thank you for choosing The Mulia Bali. We look forward to welcoming you!',
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey700,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
          ];
        },
      ),
    );
    // ✅ SHARE PDF KE DEVICE USER (Membuka Share Sheet)
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Invoice_${res.reservationNumber}.pdf',
    );
  }

   // ✅ DIPERBARUI: Method untuk Booking Services (Spa, Dining, dll) dengan Detail Item
  static Future<void> generateOrderInvoice(Order order) async {
    final pdf = pw.Document();

    final int discount = order.discountAmount; // Sudah non-nullable sesuai fix sebelumnya
    final int voucherDiscount = order.voucherDiscountAmount;
    final int subtotal = order.totalAmount + discount + voucherDiscount;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // 1. HEADER
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('The Mulia Bali', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.amber)),
                      pw.Text('Luxury Hospitality', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            // 2. INFO TAMU & ORDER
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILLED TO', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, letterSpacing: 1)),
                      pw.SizedBox(height: 4),
                      pw.Text(order.userName ?? 'Valued Guest', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      if (order.userEmail != null && order.userEmail!.isNotEmpty)
                        pw.Text(order.userEmail!, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('BOOKING DETAILS', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, letterSpacing: 1)),
                      pw.SizedBox(height: 4),
                      pw.Text('No: ${order.orderNumber}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${order.formattedDate}', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // ✅ 3. TABEL DETAIL ITEMS (DINAMIS BERDASARKAN SHOPPING CART)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                // Header Tabel
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _tableHeader('Description'),
                    _tableHeader('Qty'),
                    _tableHeader('Unit Price'),
                    _tableHeader('Total'),
                  ],
                ),
                // Loop melalui semua item di dalam order
                ...order.items.map((item) {
                  return pw.TableRow(children: [
                    _tableCell(item.itemName),
                    _tableCell('x${item.quantity}'),
                    _tableCell('IDR ${_formatPrice(item.unitPrice)}'),
                    _tableCell('IDR ${_formatPrice(item.totalPrice)}'),
                  ]);
                }).toList(),
              ],
            ),
            pw.SizedBox(height: 30),

            // 4. RINCIAN HARGA (KANAN)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 300,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _priceRow('Subtotal', subtotal),
                    if (discount > 0) _priceRow('Promo Discount', -discount, color: PdfColors.green),
                    if (voucherDiscount > 0) _priceRow('Voucher Loyalty Discount', -voucherDiscount, color: PdfColors.purple700),
                    pw.Divider(thickness: 1),
                    pw.SizedBox(height: 8),
                    _priceRow('TOTAL AMOUNT', order.totalAmount, isBold: true, fontSize: 16, color: PdfColors.amber),
                  ],
                ),
              ),
            ),
            pw.Spacer(),

            // 5. FOOTER
            pw.Center(
              child: pw.Text(
                'Thank you for experiencing The Mulia Bali services!',
                style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Invoice_${order.orderNumber}.pdf',
    );
  }

  // Helper Widget untuk Tabel
  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      ),
    );
  }

  static pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 10)),
    );
  }

  // Helper Widget untuk Baris Harga
  static pw.Widget _priceRow(
    String label,
    int amount, {
    bool isBold = false,
    double fontSize = 12,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
          pw.Text(
            'IDR ${_formatPrice(amount)}',
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
