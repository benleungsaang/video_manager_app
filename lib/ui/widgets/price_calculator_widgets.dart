import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/price_calculator_provider.dart';
import '../../models/machine.dart'; // 导入Machine模型

// 价格计算器相关的通用组件
class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PriceCalculatorProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: '搜索型号或名称...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              provider.setSearchTerm(value);
            },
          ),
        );
      },
    );
  }
}

class MachineItem extends StatelessWidget {
  final Machine part;
  final VoidCallback? onTap;

  const MachineItem({
    Key? key,
    required this.part,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: part.image.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  part.image,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported),
                    );
                  },
                ),
              )
            : Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Icon(Icons.image),
              ),
        title: Text(
          part.model,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '型号: ${part.originalModel}\n价格: ¥${part.showPrice.toStringAsFixed(2)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '¥${part.showPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
              ),
            ),
            if (part.addedCount > 0)
              Text(
                '已添加 ${part.addedCount} 次',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class AddToCartButton extends StatelessWidget {
  final Machine part;
  final String type;

  const AddToCartButton({
    Key? key,
    required this.part,
    this.type = '机器',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PriceCalculatorProvider>(
      builder: (context, provider, child) {
        return ElevatedButton.icon(
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('添加到购物车'),
          onPressed: () {
            provider.addToCart(
              type: type,
              model: part.model,
              name: part.originalModel,
              basePrice: part.originalPrice,
              actualPrice: part.showPrice,
              image: part.image,
            );
            provider.updateMachineAddedCount(part.model);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${part.model} 已添加到购物车'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        );
      },
    );
  }
}
