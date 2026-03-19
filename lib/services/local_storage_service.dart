import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _tenantIdKey = 'tenant_id';
  static const _employeeNameKey = 'employee_name';
  static const _employeeCpfKey = 'employee_cpf';

  String normalizeTenantId(String tenantId) => tenantId.trim().toUpperCase();

  String normalizeEmployeeName(String employeeName) => employeeName.trim();

  String normalizeEmployeeCpf(String employeeCpf) =>
      employeeCpf.replaceAll(RegExp(r'[^0-9]'), '');

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
    return (tenantId?.trim().isNotEmpty ?? false) &&
        (employeeName?.trim().isNotEmpty ?? false);
  }

  Future<void> saveOnboarding({
    required String tenantId,
    required String employeeName,
    String? employeeCpf,
  }) async {
    final normalizedTenantId = normalizeTenantId(tenantId);
    final normalizedEmployeeName = normalizeEmployeeName(employeeName);
    final normalizedEmployeeCpf = employeeCpf == null
        ? ''
        : normalizeEmployeeCpf(employeeCpf);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tenantIdKey, normalizedTenantId);
    await prefs.setString(_employeeNameKey, normalizedEmployeeName);
    if (normalizedEmployeeCpf.isNotEmpty) {
      await prefs.setString(_employeeCpfKey, normalizedEmployeeCpf);
    } else {
      await prefs.remove(_employeeCpfKey);
    }
  }

  Future<void> clearOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tenantIdKey);
    await prefs.remove(_employeeNameKey);
    await prefs.remove(_employeeCpfKey);
  }
}
