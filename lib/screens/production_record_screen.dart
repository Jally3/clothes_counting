import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import '../repositories/production_repository.dart';

class ProductionRecordScreen extends StatefulWidget {
  final String productCode;
  final ProductType productType;
  final DateTime? initialDateTime;

  const ProductionRecordScreen(
      {super.key,
      this.productCode = '',
      this.productType = ProductType.clothes,
      this.initialDateTime});

  @override
  State<ProductionRecordScreen> createState() => _ProductionRecordScreenState();
}

class _ProductionRecordScreenState extends State<ProductionRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  ProductType _selectedProductType = ProductType.values.first;
  final _productCodeController = TextEditingController(text: '#');
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();
  bool _isLoading = false;
  bool _isRework = false; // 返工状态，默认为false

  final ProductionRepository _repository = ProductionRepository.instance;

  @override
  void initState() {
    if (widget.productCode.isNotEmpty) {
      _productCodeController.text = widget.productCode;
    }
    _selectedProductType = widget.productType;
    _selectedDateTime = widget.initialDateTime ?? DateTime.now();
    super.initState();
    _loadExistingProductPrice();
  }

  @override
  void dispose() {
    _productCodeController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProductPrice() async {
    final productCode = _productCodeController.text.trim();
    if (productCode.isEmpty || productCode == '#') return;

    final product =
        await _repository.getProductByCode(productCode, _selectedProductType);
    if (!mounted || product == null || product.price <= 0) return;

    _unitPriceController.text = _formatPriceInput(product.price);
  }

  String _formatPriceInput(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _saveRecord() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _repository.createRecord(
          productType: _selectedProductType,
          productCode: _productCodeController.text.trim(),
          quantity: int.parse(_quantityController.text),
          unitPrice: double.parse(_unitPriceController.text.trim()),
          date: _selectedDateTime,
          isRework: _isRework,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('生产记录保存成功！'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存失败：$e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _RecordColors.background,
      appBar: AppBar(
        title: const Text(
          '录入生产记录',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _RecordColors.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: _RecordColors.primary,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 34),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                title: '产品信息',
                child: Column(
                  children: [
                    _ProductTypeField(
                      value: _selectedProductType,
                      onChanged: (ProductType? newValue) {
                        if (newValue == null) return;
                        setState(() {
                          _selectedProductType = newValue;
                        });
                        _loadExistingProductPrice();
                      },
                    ),
                    const SizedBox(height: 16),
                    _RecordTextField(
                      controller: _productCodeController,
                      label: '产品编号',
                      hintText: '请输入产品编号',
                      icon: Icons.qr_code_2_rounded,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入产品编号';
                        }
                        return null;
                      },
                      onEditingComplete: _loadExistingProductPrice,
                    ),
                    const SizedBox(height: 16),
                    _RecordTextField(
                      controller: _unitPriceController,
                      label: '单价（元）',
                      hintText: '请输入单价',
                      icon: Icons.payments_outlined,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        final price = double.tryParse(value?.trim() ?? '');
                        if (price == null) {
                          return '请输入有效的单价';
                        }
                        if (price < 0) {
                          return '单价不能小于0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _RecordTextField(
                      controller: _quantityController,
                      label: '生产数量（件）',
                      hintText: '请输入生产数量',
                      icon: Icons.add_shopping_cart_rounded,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入生产数量';
                        }
                        if (int.tryParse(value) == null ||
                            int.parse(value) <= 0) {
                          return '请输入有效的数字';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    _ReworkSwitchTile(
                      isRework: _isRework,
                      onChanged: (value) {
                        setState(() {
                          _isRework = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: '生产时间',
                child: _TimePickerTile(
                  selectedDateTime: _selectedDateTime,
                  onTap: _selectDateTime,
                ),
              ),
              const SizedBox(height: 26),
              _SaveButton(
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _saveRecord,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _RecordColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ProductTypeField extends StatelessWidget {
  const _ProductTypeField({
    required this.value,
    required this.onChanged,
  });

  final ProductType value;
  final ValueChanged<ProductType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ProductType>(
      value: value,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: _RecordInputDecoration.build(
        label: '产品类型',
        icon: Icons.checkroom_rounded,
      ),
      items: ProductType.values.map((ProductType type) {
        return DropdownMenuItem<ProductType>(
          value: type,
          child: Text(productTypeChDisplayNames[type] ?? '其他'),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? '请选择产品类型' : null,
    );
  }
}

class _RecordTextField extends StatelessWidget {
  const _RecordTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.onEditingComplete,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onEditingComplete: onEditingComplete,
      style: const TextStyle(
        color: _RecordColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: _RecordInputDecoration.build(
        label: label,
        hintText: hintText,
        icon: icon,
      ),
      validator: validator,
    );
  }
}

class _ReworkSwitchTile extends StatelessWidget {
  const _ReworkSwitchTile({
    required this.isRework,
    required this.onChanged,
  });

  final bool isRework;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _RecordColors.border),
      ),
      child: Row(
        children: [
          Icon(
            isRework
                ? Icons.remove_circle_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: isRework ? _RecordColors.warning : _RecordColors.primary,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '返工状态',
                  style: TextStyle(
                    color: _RecordColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isRework ? '已存在返工记录' : '当前为正常生产记录',
                  style: const TextStyle(
                    color: _RecordColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isRework,
            onChanged: onChanged,
            activeColor: _RecordColors.primary,
            activeTrackColor: _RecordColors.primary.withOpacity(0.28),
          ),
        ],
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({
    required this.selectedDateTime,
    required this.onTap,
  });

  final DateTime selectedDateTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _RecordColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.access_time_rounded,
              color: _RecordColors.primary,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '生产时间（可选）',
                    style: TextStyle(
                      color: _RecordColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    DateFormat('yyyy年MM月dd日 HH:mm').format(selectedDateTime),
                    style: const TextStyle(
                      color: _RecordColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: _RecordColors.textSecondary,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _RecordColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: _RecordColors.primary.withOpacity(0.28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                '保存记录',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _RecordInputDecoration {
  const _RecordInputDecoration._();

  static InputDecoration build({
    required String label,
    required IconData icon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: const TextStyle(
        color: _RecordColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(
        color: _RecordColors.textTertiary,
        fontSize: 16,
      ),
      prefixIcon: Icon(icon, color: _RecordColors.primary, size: 24),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _RecordColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _RecordColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _RecordColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _RecordColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _RecordColors.danger, width: 1.4),
      ),
    );
  }
}

class _RecordColors {
  const _RecordColors._();

  static const primary = Color(0xFF1677FF);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const background = Color(0xFFF5F7FA);
  static const border = Color(0xFFE2E8F0);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textTertiary = Color(0xFF94A3B8);
}
