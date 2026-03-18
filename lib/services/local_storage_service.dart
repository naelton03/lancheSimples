import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _tenantIdKey = 'tenant_id';
  static const _employeeNameKey = 'employee_name';
  static const _employeeCpfKey = 'employee_cpf';

  Future<String?> getTenantId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tenantIdKey);
  }

  Future<String?> getEmployeeName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_employeeNameKey);
  }

  Future<String?> getEmployeeCpf() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_employeeCpfKey);
  }

  Future<bool> isOnboardingComplete() async {
    final tenantId = await getTenantId();
    final employeeName = await getEmployeeName();
    return (tenantId?.isNotEmpty ?? false) &&
        (employeeName?.isNotEmpty ?? false);
  }

  Future<void> saveOnboarding({
    required String tenantId,
    required String employeeName,
    String? employeeCpf,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tenantIdKey, tenantId);
    await prefs.setString(_employeeNameKey, employeeName);
    if (employeeCpf != null && employeeCpf.isNotEmpty) {
      await prefs.setString(_employeeCpfKey, employeeCpf);
    } else {
      await prefs.remove(_employeeCpfKey);
    }
  }
}
