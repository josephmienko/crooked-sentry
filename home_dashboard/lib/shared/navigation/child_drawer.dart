import 'package:flutter/material.dart';
import '../../core/models/navigation_models.dart';

/// Child menu drawer that can be shown as a Drawer or Dialog
class ChildDrawer extends StatefulWidget {
  final NavItem parentItem;
  final int parentIndex;
  final int? selectedChildIndex;
  final int? selectedGrandchildIndex;
  final Set<int> expandedChildren;
  final Function(int) onChildTap;
  final Function(int, int) onGrandchildTap;
  final bool isDialog;
  final VoidCallback? onBack;

  const ChildDrawer({
    Key? key,
    required this.parentItem,
    required this.parentIndex,
    required this.selectedChildIndex,
    required this.selectedGrandchildIndex,
    required this.expandedChildren,
    required this.onChildTap,
    required this.onGrandchildTap,
    this.isDialog = false,
    this.onBack,
  }) : super(key: key);

  @override
  State<ChildDrawer> createState() => _ChildDrawerState();
}

class _ChildDrawerState extends State<ChildDrawer> {
  late Set<int> _localExpandedChildren;

  @override
  void initState() {
    super.initState();
    _localExpandedChildren = Set.from(widget.expandedChildren);
  }

  void _toggleExpanded(int index) {
    setState(() {
      if (_localExpandedChildren.contains(index)) {
        _localExpandedChildren.remove(index);
      } else {
        _localExpandedChildren.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        if (widget.onBack != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              leading: const Icon(Icons.arrow_back),
              title: const Text('Back'),
              onTap: widget.onBack,
            ),
          ),
        if (widget.onBack != null) const Divider(),
        if (!widget.isDialog)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.parentItem.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        if (!widget.isDialog && widget.onBack == null) const Divider(),
        for (int j = 0; j < widget.parentItem.children!.length; j++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              selected: widget.selectedChildIndex == j &&
                  widget.selectedGrandchildIndex == null,
              selectedTileColor: colorScheme.secondaryContainer,
              trailing: widget.parentItem.children![j].hasGrandchildren
                  ? Icon(
                      _localExpandedChildren.contains(j)
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 20,
                    )
                  : null,
              title: Text(widget.parentItem.children![j].label),
              onTap: () {
                if (widget.parentItem.children![j].hasGrandchildren) {
                  _toggleExpanded(j);
                } else {
                  widget.onChildTap(j);
                }
              },
            ),
          ),
          // Show grandchildren if this child is expanded
          if (_localExpandedChildren.contains(j) &&
              widget.parentItem.children![j].hasGrandchildren)
            for (int k = 0;
                k < widget.parentItem.children![j].grandchildren!.length;
                k++)
              Padding(
                padding: EdgeInsets.only(
                  left: widget.isDialog ? 32 : 24,
                  top: 4,
                  bottom: 4,
                  right: 4,
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  selected: widget.selectedChildIndex == j &&
                      widget.selectedGrandchildIndex == k,
                  selectedTileColor: colorScheme.secondaryContainer,
                  title: Text(
                      widget.parentItem.children![j].grandchildren![k].label),
                  onTap: () => widget.onGrandchildTap(j, k),
                ),
              ),
        ],
      ],
    );
  }
}
