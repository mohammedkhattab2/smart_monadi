import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';
import 'package:smart_monadi/features/location/domain/repositories/bus_location_repository.dart';
import 'package:smart_monadi/features/notifications/domain/controllers/active_trip_controller.dart';
import 'package:smart_monadi/features/passenger/data/repositories/passenger_repository.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';

const LatLng _saudiDefaultLatLng = LatLng(24.7136, 46.6753);

class ParentScreen extends StatefulWidget {
  const ParentScreen({
    super.key,
    required this.repository,
    required this.locationRepository,
    required this.currentUserId,
    required this.activeTripController,
  });

  final PassengerRepository repository;
  final BusLocationRepository locationRepository;
  final String currentUserId;
  final ActiveTripController activeTripController;

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Passenger>> _studentsStream() {
    final repo = widget.repository;
    if (repo is FirestorePassengerRepository) {
      return repo.watchPassengersByParentId(widget.currentUserId);
    }

    return repo.watchPassengers().map(
      (items) => items
          .where((item) => item.parentId == widget.currentUserId)
          .toList(growable: false),
    );
  }

  Stream<Map<String, dynamic>?> _parentProfileStream() {
    return _firestore
        .collection('users')
        .doc(widget.currentUserId)
        .snapshots()
        .map((doc) => doc.data());
  }

  Future<void> _setFixedDropoff() async {
    final current = await _firestore
        .collection('users')
        .doc(widget.currentUserId)
        .get();
    if (!mounted) {
      return;
    }

    final data = current.data() ?? <String, dynamic>{};
    final existingLat = (data['fixedDropoffLat'] as num?)?.toDouble();
    final existingLng = (data['fixedDropoffLng'] as num?)?.toDouble();

    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => _LocationPickerPage(
          title: 'اختيار موقع الوصول الثابت',
          initialTarget: LatLng(
            existingLat ?? _saudiDefaultLatLng.latitude,
            existingLng ?? _saudiDefaultLatLng.longitude,
          ),
          initialSelection: existingLat != null && existingLng != null
              ? LatLng(existingLat, existingLng)
              : null,
        ),
      ),
    );

    if (!mounted || picked == null) {
      return;
    }

    await _firestore.collection('users').doc(widget.currentUserId).set({
      'fixedDropoffLat': picked.latitude,
      'fixedDropoffLng': picked.longitude,
      'fixedDropoffAddress':
          '${picked.latitude.toStringAsFixed(6)}, ${picked.longitude.toStringAsFixed(6)}',
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> _openStudentForm({Passenger? student}) async {
    final profile = await _firestore
        .collection('users')
        .doc(widget.currentUserId)
        .get();
    if (!mounted) {
      return;
    }

    final data = profile.data() ?? <String, dynamic>{};
    final dropoffLat = (data['fixedDropoffLat'] as num?)?.toDouble();
    final dropoffLng = (data['fixedDropoffLng'] as num?)?.toDouble();
    final dropoffAddress = (data['fixedDropoffAddress'] ?? '').toString();

    if (dropoffLat == null || dropoffLng == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدد موقع الوصول الثابت أولًا لولي الأمر.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _StudentFormPage(
          repository: widget.repository,
          parentId: widget.currentUserId,
          dropoffAddress: dropoffAddress,
          existing: student,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.primaryContainer.withValues(alpha: 0.72),
                  colorScheme.secondaryContainer.withValues(alpha: 0.42),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(22.r),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46.w,
                      height: 46.w,
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Icon(
                        Icons.family_restroom,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'لوحة ولي الأمر',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'إدارة الطلاب، المواعيد، والمتابعة الحية في مكان واحد',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.onPrimaryContainer,
                      foregroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _ParentDriverLiveLocationPage(
                            locationRepository: widget.locationRepository,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('موقع السواق لايف'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          StreamBuilder<Map<String, dynamic>?>(
            stream: _parentProfileStream(),
            builder: (context, snapshot) {
              final data = snapshot.data ?? <String, dynamic>{};
              final fixedDropoffAddress = (data['fixedDropoffAddress'] ?? '')
                  .toString();
              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.pin_drop_outlined,
                          color: colorScheme.primary,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'موقع الوصول الثابت',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      fixedDropoffAddress.isEmpty
                          ? 'لم يتم تحديد موقع الوصول بعد'
                          : fixedDropoffAddress,
                      style: theme.textTheme.bodyMedium,
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _setFixedDropoff,
                        icon: const Icon(Icons.edit_location_alt_outlined),
                        label: const Text('تحديد / تعديل موقع الوصول'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 14.h),
          _BusLiveStatusCard(locationRepository: widget.locationRepository),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  'الطلاب',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              SizedBox(
                width: 148.w,
                child: FilledButton.icon(
                  onPressed: () => _openStudentForm(),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('إضافة طالب'),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          StreamBuilder<List<Passenger>>(
            stream: _studentsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final students = snapshot.data ?? const <Passenger>[];
              if (students.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    'لا يوجد طلاب مضافين بعد.',
                    style: theme.textTheme.bodyMedium,
                  ),
                );
              }

              return Column(
                children: students
                    .map((student) {
                      final shortId = student.shortId.isEmpty
                          ? student.id
                                .substring(
                                  0,
                                  student.id.length >= 6
                                      ? 6
                                      : student.id.length,
                                )
                                .toUpperCase()
                          : student.shortId;
                      final statusText = student.isPickedUp
                          ? 'تم الاستلام'
                          : student.geofenceState == 'approaching'
                          ? 'السائق قريب'
                          : 'في الانتظار';

                      return Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: 10.h),
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.surface,
                              colorScheme.surfaceContainerHighest.withValues(
                                alpha: 0.45,
                              ),
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'اسم الطالب: ${student.name}',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      if (student.dependentName
                                          .trim()
                                          .isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(top: 2.h),
                                          child: Text(
                                            'اسم التابع: ${student.dependentName}',
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 5.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(20.r),
                                  ),
                                  child: Text(
                                    'ID: $shortId',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            _StudentInfoLine(
                              icon: Icons.badge_outlined,
                              label: 'هوية الطالب',
                              value: student.studentNationalId,
                            ),
                            _StudentInfoLine(
                              icon: Icons.cake_outlined,
                              label: 'تاريخ الميلاد',
                              value: student.birthDate,
                            ),
                            _StudentInfoLine(
                              icon: Icons.access_time,
                              label: 'المواعيد',
                              value:
                                  '${student.pickupTime} ذهاب | ${student.returnTime} عودة',
                            ),
                            _StudentInfoLine(
                              icon: Icons.location_on_outlined,
                              label: 'موقع الاستلام',
                              value: student.address,
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10.w,
                                      vertical: 8.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusBg(statusText, colorScheme),
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                    child: Text(
                                      'الحالة: $statusText',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _openStudentForm(student: student),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('تعديل'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _statusBg(String status, ColorScheme colorScheme) {
    if (status == 'تم الاستلام') {
      return colorScheme.tertiaryContainer;
    }
    if (status == 'السائق قريب') {
      return colorScheme.secondaryContainer;
    }
    return colorScheme.surfaceContainerHighest;
  }
}

class _BusLiveStatusCard extends StatelessWidget {
  const _BusLiveStatusCard({required this.locationRepository});

  final BusLocationRepository locationRepository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: StreamBuilder<BusLocation?>(
          stream: locationRepository.watchBusLocation(),
          builder: (context, snapshot) {
            final bus = snapshot.data;
            if (bus == null) {
              return Row(
                children: [
                  Icon(Icons.directions_bus_filled, color: colorScheme.primary),
                  SizedBox(width: 8.w),
                  const Expanded(
                    child: Text('Bus Live Status: غير متاح حاليًا'),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.directions_bus_filled,
                      color: colorScheme.primary,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Bus Live Status',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  'الموقع الحالي: ${bus.latitude.toStringAsFixed(6)}, ${bus.longitude.toStringAsFixed(6)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StudentInfoLine extends StatelessWidget {
  const _StudentInfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.w, color: theme.colorScheme.primary),
          SizedBox(width: 6.w),
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _StudentFormPage extends StatefulWidget {
  const _StudentFormPage({
    required this.repository,
    required this.parentId,
    required this.dropoffAddress,
    this.existing,
  });

  final PassengerRepository repository;
  final String parentId;
  final String dropoffAddress;
  final Passenger? existing;

  @override
  State<_StudentFormPage> createState() => _StudentFormPageState();
}

class _StudentFormPageState extends State<_StudentFormPage> {
  static final RegExp _studentNationalIdRegex = RegExp(r'^\d{10}$');
  static final RegExp _timeRegex = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _dependentNameController;
  late final TextEditingController _nationalIdController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _pickupTimeController;
  late final TextEditingController _returnTimeController;
  late final TextEditingController _pickupAddressController;

  double? _pickupLat;
  double? _pickupLng;
  bool _isSaving = false;
  bool _isResolvingCurrentLocation = false;

  String? _pickupCoordinatesHelper() {
    final lat = _pickupLat;
    final lng = _pickupLng;
    if (lat == null || lng == null) {
      return null;
    }

    return 'الإحداثيات: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _dependentNameController = TextEditingController();
    _nationalIdController = TextEditingController(
      text: existing?.studentNationalId ?? '',
    );
    _birthDateController = TextEditingController(
      text: existing?.birthDate ?? '',
    );
    _pickupTimeController = TextEditingController(
      text: existing?.pickupTime ?? '07:30',
    );
    _returnTimeController = TextEditingController(
      text: existing?.returnTime ?? '14:30',
    );
    _pickupAddressController = TextEditingController(
      text: existing?.address ?? '',
    );
    _pickupLat = existing?.latitude;
    _pickupLng = existing?.longitude;
    _hydrateDependentName();
  }

  Future<void> _hydrateDependentName() async {
    final existing = widget.existing;
    if (existing == null) {
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('passengers')
        .doc(existing.id)
        .get();
    if (!mounted) {
      return;
    }

    final value = (snap.data()?['dependentName'] ?? '').toString();
    _dependentNameController.text = value;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dependentNameController.dispose();
    _nationalIdController.dispose();
    _birthDateController.dispose();
    _pickupTimeController.dispose();
    _returnTimeController.dispose();
    _pickupAddressController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 8, now.month, now.day),
      firstDate: DateTime(1990, 1, 1),
      lastDate: now,
    );
    if (picked == null) {
      return;
    }
    final formatted =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    _birthDateController.text = formatted;
  }

  Future<void> _pickPickupLocation() async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => _LocationPickerPage(
          title: 'اختيار موقع الاستلام',
          initialTarget: LatLng(
            _pickupLat ?? _saudiDefaultLatLng.latitude,
            _pickupLng ?? _saudiDefaultLatLng.longitude,
          ),
          initialSelection: _pickupLat != null && _pickupLng != null
              ? LatLng(_pickupLat!, _pickupLng!)
              : null,
        ),
      ),
    );
    if (picked == null) {
      return;
    }

    final address = await _resolveAddressFromCoordinates(
      picked.latitude,
      picked.longitude,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _pickupLat = picked.latitude;
      _pickupLng = picked.longitude;
      _pickupAddressController.text = address;
    });
  }

  Future<String> _resolveAddressFromCoordinates(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) {
        return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
      }

      final mark = marks.first;
      final parts = <String>[
        mark.street ?? '',
        mark.subLocality ?? '',
        mark.locality ?? '',
        mark.administrativeArea ?? '',
      ].where((part) => part.trim().isNotEmpty).toList(growable: false);

      if (parts.isEmpty) {
        return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
      }

      return parts.join('، ');
    } catch (_) {
      return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    }
  }

  Future<Position?> _resolveCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('خدمة الموقع غير مفعلة');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw StateError('تم رفض إذن الموقع');
    }

    if (permission == LocationPermission.deniedForever) {
      throw StateError('إذن الموقع مرفوض نهائيًا');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _useCurrentLocation() async {
    if (_isResolvingCurrentLocation) {
      return;
    }

    setState(() {
      _isResolvingCurrentLocation = true;
    });

    try {
      final position = await _resolveCurrentPosition();
      if (!mounted || position == null) {
        return;
      }

      final address = await _resolveAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _pickupLat = position.latitude;
        _pickupLng = position.longitude;
        _pickupAddressController.text = address;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is StateError ? error.message : 'تعذر تحديد الموقع';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingCurrentLocation = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_pickupLat == null || _pickupLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد موقع الاستلام للطالب.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final existing = widget.existing;
      if (existing == null) {
        final repo = widget.repository;
        if (repo is FirestorePassengerRepository) {
          await repo.createPassengerForParent(
            parentId: widget.parentId,
            studentNationalId: _nationalIdController.text.trim(),
            birthDate: _birthDateController.text.trim(),
            name: _nameController.text.trim(),
            dependentName: _dependentNameController.text.trim(),
            phone: '',
            address: _pickupAddressController.text.trim(),
            pickupTime: _pickupTimeController.text.trim(),
            returnTime: _returnTimeController.text.trim(),
            latitude: _pickupLat!,
            longitude: _pickupLng!,
          );
        } else {
          final doc = FirebaseFirestore.instance.collection('passengers').doc();
          await doc.set({
            'parentId': widget.parentId,
            'shortId': doc.id
                .substring(0, doc.id.length >= 6 ? 6 : doc.id.length)
                .toUpperCase(),
            'studentNationalId': _nationalIdController.text.trim(),
            'birthDate': _birthDateController.text.trim(),
            'name': _nameController.text.trim(),
            'dependentName': _dependentNameController.text.trim(),
            'phone': '',
            'address': _pickupAddressController.text.trim(),
            'pickupTime': _pickupTimeController.text.trim(),
            'returnTime': _returnTimeController.text.trim(),
            'latitude': _pickupLat,
            'longitude': _pickupLng,
            'isPickedUp': false,
            'geofenceState': 'idle',
            'updatedAt': Timestamp.now(),
          });
        }
      } else {
        await FirebaseFirestore.instance
            .collection('passengers')
            .doc(existing.id)
            .set({
              'parentId': widget.parentId,
              'studentNationalId': _nationalIdController.text.trim(),
              'birthDate': _birthDateController.text.trim(),
              'dependentName': _dependentNameController.text.trim(),
              'updatedAt': Timestamp.now(),
            }, SetOptions(merge: true));

        await widget.repository.upsertPassenger(
          id: existing.id,
          name: _nameController.text.trim(),
          phone: existing.phone,
          address: _pickupAddressController.text.trim(),
          pickupTime: _pickupTimeController.text.trim(),
          returnTime: _returnTimeController.text.trim(),
          latitude: _pickupLat,
          longitude: _pickupLng,
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'إضافة طالب' : 'تعديل بيانات الطالب',
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إضافة تابع',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    const Text(
                      'هذا البند داخل إضافة الطالب لتسجيل الطالب كتابع لولي الأمر الحالي.',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Text('موقع الوصول الثابت: ${widget.dropoffAddress}'),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم الطالب'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'الاسم مطلوب'
                    : null,
              ),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _nationalIdController,
                maxLength: 10,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'هوية الطالب (10 أرقام)',
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (!_studentNationalIdRegex.hasMatch(text)) {
                    return 'هوية الطالب يجب أن تكون 10 أرقام';
                  }
                  return null;
                },
              ),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _birthDateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'تاريخ الميلاد (YYYY-MM-DD)',
                ),
                onTap: _pickBirthDate,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'تاريخ الميلاد مطلوب'
                    : null,
              ),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _pickupAddressController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'موقع الاستلام',
                  helperText: _pickupCoordinatesHelper(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'حدد موقع الاستلام'
                    : null,
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickPickupLocation,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('تحديد على الخريطة'),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isResolvingCurrentLocation
                          ? null
                          : _useCurrentLocation,
                      icon: _isResolvingCurrentLocation
                          ? SizedBox(
                              width: 16.w,
                              height: 16.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.my_location_outlined),
                      label: const Text('موقعي الحالي'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _pickupTimeController,
                decoration: const InputDecoration(
                  labelText: 'وقت الاستلام (HH:mm)',
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (!_timeRegex.hasMatch(text)) {
                    return 'أدخل وقتًا صحيحًا مثل 07:30';
                  }
                  return null;
                },
              ),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _returnTimeController,
                decoration: const InputDecoration(
                  labelText: 'وقت العودة (HH:mm)',
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (!_timeRegex.hasMatch(text)) {
                    return 'أدخل وقتًا صحيحًا مثل 14:30';
                  }
                  return null;
                },
              ),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _dependentNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم التابع (اختياري)',
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('حفظ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParentDriverLiveLocationPage extends StatelessWidget {
  const _ParentDriverLiveLocationPage({required this.locationRepository});

  final BusLocationRepository locationRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('موقع السواق لايف')),
      body: StreamBuilder<BusLocation?>(
        stream: locationRepository.watchBusLocation(),
        builder: (context, snapshot) {
          final bus = snapshot.data;
          if (bus == null) {
            return GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _saudiDefaultLatLng,
                zoom: 9,
              ),
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
            );
          }

          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(bus.latitude, bus.longitude),
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('driver_live'),
                position: LatLng(bus.latitude, bus.longitude),
                infoWindow: const InfoWindow(title: 'موقع السائق'),
              ),
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
          );
        },
      ),
    );
  }
}

class _LocationPickerPage extends StatefulWidget {
  const _LocationPickerPage({
    required this.title,
    required this.initialTarget,
    this.initialSelection,
  });

  final String title;
  final LatLng initialTarget;
  final LatLng? initialSelection;

  @override
  State<_LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<_LocationPickerPage> {
  late LatLng _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection ?? widget.initialTarget;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.initialTarget,
                zoom: 14,
              ),
              markers: {
                Marker(markerId: const MarkerId('picked'), position: _selected),
              },
              onTap: (position) {
                setState(() {
                  _selected = position;
                });
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12.w),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: const Text('تأكيد الموقع'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
