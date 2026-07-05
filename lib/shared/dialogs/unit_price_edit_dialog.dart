import 'package:flutter/material.dart';

import '../../extensions/double_extension.dart';

Future<double?> showUnitPriceEditDialog({
  required BuildContext context,
  required String productCode,
  required double initialPrice,
}) {
  return showDialog<double>(
    context: context,
    builder: (context) => _UnitPriceEditDialog(
      title: '编辑单价 $productCode',
      initialPrice: initialPrice,
      labelText: '单价',
    ),
  );
}

Future<double?> showBatchUnitPriceEditDialog({
  required BuildContext context,
  required String productTypeName,
  required int productCodeCount,
}) {
  return showDialog<double>(
    context: context,
    builder: (context) => _UnitPriceEditDialog(
      title: '批量修改$productTypeName单价',
      description: '将修改当前列表中的 $productCodeCount 个编号',
      labelText: '新单价',
    ),
  );
}

class _UnitPriceEditDialog extends StatefulWidget {
  const _UnitPriceEditDialog({
    required this.title,
    required this.labelText,
    this.initialPrice,
    this.description,
  });

  final String title;
  final String labelText;
  final double? initialPrice;
  final String? description;

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
      text: widget.initialPrice == null
          ? ''
          : _formatPriceInput(widget.initialPrice!),
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
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.description != null) ...[
              Text(
                widget.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: widget.labelText,
                prefixIcon: const Icon(Icons.payments_outlined),
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
          ],
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
  return value.toTrimmedPriceString();
}
