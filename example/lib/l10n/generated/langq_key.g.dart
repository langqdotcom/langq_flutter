// GENERATED CODE - DO NOT MODIFY BY HAND
// *************************************************
// Auto-generated Dart file
// *************************************************

import 'package:langq_localization/langq.dart';

class LangQKey {
  /// Base: Hello World!
  static String helloWorld() {
    return LangQ.text('hello.world');
  }

  /// Base: Hello, {userName}!
  static String welcomeMessage({required String userName}) {
    return LangQ.text('welcome.message', args: {'userName': userName});
  }

  /// Base: You have {messageCount, plural, =0{no new messages} one{1 new message} other{{messageCount} new messages}}.
  static String messageNotification({required num messageCount}) {
    return LangQ.text(
      'message.notification',
      args: {'messageCount': '$messageCount'},
    );
  }

  /// Base: You have {ticketCount, plural, =0{no new tickets} one{1 new ticket} other{{ticketCount} new tickets}}.
  static String messageNewtickets({required num ticketCount}) {
    return LangQ.text(
      'message.newTickets',
      args: {'ticketCount': '$ticketCount'},
    );
  }

  /// Base: Your order with {itemCount, plural, =0{no items} one{1 item} other{{itemCount} items}} worth {amount} placed on {date}.
  static String messageOrder({
    required String amount,
    required String date,
    required num itemCount,
  }) {
    return LangQ.text(
      'message.order',
      args: {'amount': amount, 'date': date, 'itemCount': '$itemCount'},
    );
  }

  /// Base: {departmentCount} departments have {teamCount} teams working on {projectCount} projects with {taskCount} open tasks.
  static String informationDepartmentandtask({
    required String departmentCount,
    required String projectCount,
    required String taskCount,
    required String teamCount,
  }) {
    return LangQ.text(
      'information.departmentAndTask',
      args: {
        'departmentCount': departmentCount,
        'projectCount': projectCount,
        'taskCount': taskCount,
        'teamCount': teamCount,
      },
    );
  }

  /// Base: {invoiceCount, plural, =0{There are no invoices} one{There is 1 invoice} other{There are # invoices}} totaling {amount} are overdue.
  static String messageOverdue({
    required String amount,
    required num invoiceCount,
  }) {
    return LangQ.text(
      'message.overdue',
      args: {'amount': amount, 'invoiceCount': '$invoiceCount'},
    );
  }

  /// Base: {userCount, plural, =0{no users} one{1 user} other{{userCount} users}} are viewing {documentCount, plural, =0{no documents} one{1 document} other{{documentCount} documents}}.
  static String messageDocumentview({
    required num documentCount,
    required num userCount,
  }) {
    return LangQ.text(
      'message.documentView',
      args: {'documentCount': '$documentCount', 'userCount': '$userCount'},
    );
  }
}
