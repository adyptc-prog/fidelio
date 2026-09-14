import '../entities/customer_record.dart';

/// Customers (with a birthday set) whose birthday is today and who have not
/// already been prompted for a reward this calendar year.
List<CustomerRecord> customersWithBirthdayToday(
  List<CustomerRecord> customers, {
  required DateTime today,
}) {
  return customers.where((customer) {
    if (!customer.hasBirthday) {
      return false;
    }
    if (customer.birthMonth != today.month || customer.birthDay != today.day) {
      return false;
    }
    return customer.lastBirthdayPromptYear != today.year;
  }).toList();
}

/// The next date/time at which [month]/[day] occurs at [hour]:[minute],
/// strictly after [from]. Used to schedule a yearly-recurring reminder.
DateTime nextBirthdayOccurrence({
  required int month,
  required int day,
  required DateTime from,
  int hour = 9,
  int minute = 0,
}) {
  var next = DateTime(from.year, month, day, hour, minute);
  if (!next.isAfter(from)) {
    next = DateTime(from.year + 1, month, day, hour, minute);
  }
  return next;
}
