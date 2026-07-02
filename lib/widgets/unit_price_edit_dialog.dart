import 'package:flutter/material.dart';

Future<double?> showUnitPriceEditDialog({
  required BuildContext context,
  required String productCode,
  required double initialPrice,
}) {
  return showDialog<double>(
    context: context,
    builder: (context) => _UnitPriceEditDialog(
      productCode: productCode,
      initialPrice: initialPrice,
    ),
  );
}

class _UnitPriceEditDialog extends StatefulWidget {
  const _UnitPriceEditDialog({
    required this.productCode,
    required this.initialPrice,
  });

  final String productCode;
  final double initialPrice;

  @override
  State<_UnitPriceEditDialog> createState() => _UnitPriceEditDialogState();
}

class _UnitPriceEditDialogState extends State<_UnitPriceEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatPriceInput(widget.initialPrice),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(double.parse(_controller.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('编辑单价 ${widget.productCode}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '单价',
            prefixIcon: Icon(Icons.payments_outlined),
            suffixText: '元',
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
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

String _formatPriceInput(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}
