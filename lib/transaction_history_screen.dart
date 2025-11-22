import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Transaction History',
          style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4A90E2),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF4A90E2),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
          ),
          isScrollable: false,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Borrow'),
            Tab(text: 'Lent'),
            Tab(text: 'Sell'),
            Tab(text: 'Swap'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllTransactions(),
          _buildBorrowedItems(),
          _buildLentItems(),
          _buildSoldItems(),
          _buildSwappedItems(),
        ],
      ),
    );
  }

  Widget _buildAllTransactions() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('transactions')
          .where('userId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('❌ Transaction query error: ${snapshot.error}');
          return _buildErrorWidget();
        }

        final docs = snapshot.data?.docs ?? [];

        final uniqueTransactions = <String, QueryDocumentSnapshot>{};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          final key =
              '${data['itemId'] ?? ''}_${data['otherUserId'] ?? ''}_${data['type'] ?? ''}_${data['role'] ?? ''}';
          final previousDoc = uniqueTransactions[key];

          if (previousDoc == null) {
            uniqueTransactions[key] = doc;
          } else {
            final prevData = previousDoc.data() as Map<String, dynamic>?;
            final currData = data;

            final prevHasDeadline = prevData?['deadline'] != null;
            final currHasDeadline = currData['deadline'] != null;

            if (currHasDeadline && !prevHasDeadline) {
              uniqueTransactions[key] = doc;
            } else if (!currHasDeadline && prevHasDeadline) {
            } else {
              final prevCreatedAt = prevData?['createdAt'];
              final currCreatedAt = currData['createdAt'];
              if (prevCreatedAt == null ||
                  (currCreatedAt != null &&
                      prevCreatedAt.compareTo(currCreatedAt) < 0)) {
                uniqueTransactions[key] = doc;
              }
            }
          }
        }

        final filteredTransactions = uniqueTransactions.values.toList();

        if (filteredTransactions.isEmpty) {
          return _buildEmptyWidget('No transactions yet', Icons.receipt_long);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredTransactions.length,
          itemBuilder: (context, index) {
            final transaction =
                filteredTransactions[index].data() as Map<String, dynamic>;
            return _buildTransactionCard(transaction);
          },
        );
      },
    );
  }

  Widget _buildBorrowedItems() {
    return StreamBuilder(
      stream: _firestore
          .collection('transactions')
          .where('userId', isEqualTo: currentUserId)
          .where('type', isEqualTo: 'borrow')
          .where('role', isEqualTo: 'requester')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Borrowed items query error: ${snapshot.error}');
          return _buildErrorWidget();
        }

        final docs = snapshot.data?.docs ?? [];

        final uniqueTransactions = <String, QueryDocumentSnapshot>{};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          final key = '${data['itemId'] ?? ''}_${data['otherUserId'] ?? ''}';
          final previousDoc = uniqueTransactions[key];

          if (previousDoc == null) {
            uniqueTransactions[key] = doc;
          } else {
            final prevData = previousDoc.data() as Map<String, dynamic>?;
            final currData = data;

            final prevHasDeadline = prevData?['deadline'] != null;
            final currHasDeadline = currData['deadline'] != null;

            if (currHasDeadline && !prevHasDeadline) {
              uniqueTransactions[key] = doc;
            } else if (!currHasDeadline && prevHasDeadline) {
            } else {
              final prevCreatedAt = prevData?['createdAt'];
              final currCreatedAt = currData['createdAt'];
              if (prevCreatedAt == null ||
                  (currCreatedAt != null &&
                      prevCreatedAt.compareTo(currCreatedAt) < 0)) {
                uniqueTransactions[key] = doc;
              }
            }
          }
        }

        final filteredTransactions = uniqueTransactions.values.toList();

        if (filteredTransactions.isEmpty) {
          return _buildEmptyWidget('No borrow requests yet', Icons.download);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredTransactions.length,
          itemBuilder: (context, index) {
            final transaction =
                filteredTransactions[index].data() as Map<String, dynamic>;
            return _buildBorrowTransactionCard(transaction);
          },
        );
      },
    );
  }

  Widget _buildLentItems() {
    return StreamBuilder(
      stream: _firestore
          .collection('transactions')
          .where('userId', isEqualTo: currentUserId)
          .where('type', isEqualTo: 'borrow')
          .where('role', isEqualTo: 'provider')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Lent items query error: ${snapshot.error}');
          return _buildErrorWidget();
        }

        final docs = snapshot.data?.docs ?? [];

        final uniqueTransactions = <String, QueryDocumentSnapshot>{};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          final key = '${data['itemId'] ?? ''}_${data['otherUserId'] ?? ''}';
          final previousDoc = uniqueTransactions[key];
          if (previousDoc == null) {
            uniqueTransactions[key] = doc;
          } else {
            final prevData = previousDoc.data() as Map<String, dynamic>?;
            final currData = data;

            final prevHasDeadline = prevData?['deadline'] != null;
            final currHasDeadline = currData['deadline'] != null;

            if (currHasDeadline && !prevHasDeadline) {
              uniqueTransactions[key] = doc;
            } else if (!currHasDeadline && prevHasDeadline) {
            } else {
              final prevCreatedAt = prevData?['createdAt'];
              final currCreatedAt = currData['createdAt'];
              if (prevCreatedAt == null ||
                  (currCreatedAt != null &&
                      prevCreatedAt.compareTo(currCreatedAt) < 0)) {
                uniqueTransactions[key] = doc;
              }
            }
          }
        }
        final filteredTransactions = uniqueTransactions.values.toList();

        if (filteredTransactions.isEmpty) {
          return _buildEmptyWidget('No lent items yet', Icons.upload);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredTransactions.length,
          itemBuilder: (context, index) {
            final transaction =
                filteredTransactions[index].data() as Map<String, dynamic>;
            return _buildLentTransactionCard(transaction);
          },
        );
      },
    );
  }

  Widget _buildLentTransactionCard(Map<String, dynamic> transaction) {
    final itemTitle = transaction['itemTitle'] ?? 'Unknown Item';
    final otherUserName = transaction['otherUserName'] ?? 'Unknown User';
    final deadline = transaction['deadline'] as Timestamp?;
    final timestamp = transaction['createdAt'] as Timestamp?;
    final status = transaction['status'] ?? 'pending';

    Color statusColor;
    String statusText;
    IconData statusIcon;
    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        statusText = 'LENT';
        statusIcon = Icons.check_circle;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = 'COMPLETED';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'REJECTED';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'PENDING';
        statusIcon = Icons.access_time;
    }

    bool isOverdue = false;
    if (status == 'accepted' && deadline != null) {
      isOverdue = DateTime.now().isAfter(deadline.toDate());
      if (isOverdue) {
        statusColor = Colors.red;
        statusText = 'OVERDUE';
        statusIcon = Icons.warning;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.upload, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Lent to $otherUserName',
                      style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (deadline != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: isOverdue ? Colors.red : Colors.purple,
                ),
                const SizedBox(width: 8),
                Text(
                  'Return by: ${DateFormat('MMM d, yyyy').format(deadline.toDate())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverdue ? Colors.red : Colors.purple,
                    fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
          if (timestamp != null) ...[
            const SizedBox(height: 8),
            Text(
              'Lent: ${_formatTimestamp(timestamp.toDate())}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSoldItems() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('transactions')
          .where('userId', isEqualTo: currentUserId)
          .where('type', isEqualTo: 'sell')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Sold items query error: ${snapshot.error}');
          return _buildErrorWidget();
        }

        final docs = snapshot.data?.docs ?? [];

        final uniqueTransactions = <String, QueryDocumentSnapshot>{};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          final key = '${data['itemId'] ?? ''}_${data['otherUserId'] ?? ''}';
          final previousDoc = uniqueTransactions[key];

          if (previousDoc == null) {
            uniqueTransactions[key] = doc;
          } else {
            final prevData = previousDoc.data() as Map<String, dynamic>?;
            final prevName = prevData?['otherUserName'] ?? '';
            final currName = data['otherUserName'] ?? '';

            if (currName.isNotEmpty &&
                currName != 'Unknown Buyer' &&
                currName != 'Unknown User' &&
                (prevName == 'Unknown Buyer' ||
                    prevName == 'Unknown User' ||
                    prevName.isEmpty)) {
              uniqueTransactions[key] = doc;
            }
          }
        }

        final filteredTransactions = uniqueTransactions.values.toList();

        if (filteredTransactions.isEmpty) {
          return _buildEmptyWidget('No sale requests yet', Icons.attach_money);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredTransactions.length,
          itemBuilder: (context, index) {
            final transaction =
                filteredTransactions[index].data() as Map<String, dynamic>;
            return _buildSoldTransactionCard(transaction);
          },
        );
      },
    );
  }

  Widget _buildSwappedItems() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('transactions')
          .where('userId', isEqualTo: currentUserId)
          .where('type', isEqualTo: 'swap')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('❌ Swap query error: ${snapshot.error}');
          return _buildErrorWidget();
        }

        final swaps = snapshot.data?.docs ?? [];

        if (swaps.isEmpty) {
          return _buildEmptyWidget('No swap requests yet', Icons.swap_horiz);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: swaps.length,
          itemBuilder: (context, index) {
            final swap = swaps[index].data() as Map<String, dynamic>;
            return _buildSwapTransactionCard(swap);
          },
        );
      },
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final type = transaction['type'] ?? '';
    final status = transaction['status'] ?? 'pending';
    final role = transaction['role'] ?? '';
    final itemTitle = transaction['itemTitle'] ?? 'Unknown Item';
    final timestamp = transaction['createdAt'] as Timestamp?;
    final otherUserName = transaction['otherUserName'] ?? 'Unknown User';
    final amount = transaction['amount'] as double?;
    final deadline = transaction['deadline'] as Timestamp?;

    IconData icon;
    Color color;
    String action;
    String description;

    if (role == 'requester') {
      switch (type) {
        case 'borrow':
          icon = Icons.download;
          color = Colors.green;
          action = 'Borrow Request';
          description = status == 'accepted'
              ? 'Borrowed from $otherUserName'
              : status == 'rejected'
              ? 'Request rejected by $otherUserName'
              : 'Requested to borrow from $otherUserName';
          break;
        case 'sell':
          icon = Icons.shopping_cart;
          color = Colors.orange;
          action = 'Purchase Request';
          description = status == 'accepted'
              ? 'Bought from $otherUserName'
              : status == 'rejected'
              ? 'Purchase rejected by $otherUserName'
              : 'Requested to buy from $otherUserName';
          break;
        case 'swap':
          icon = Icons.swap_horiz;
          color = Colors.blue;
          action = 'Swap Request';
          description = status == 'accepted'
              ? 'Swapped with $otherUserName'
              : status == 'rejected'
              ? 'Swap rejected by $otherUserName'
              : 'Requested to swap with $otherUserName';
          break;
        default:
          icon = Icons.help;
          color = Colors.grey;
          action = 'Request';
          description = 'Transaction with $otherUserName';
      }
    } else {
      switch (type) {
        case 'borrow':
          icon = Icons.upload;
          color = Colors.green;
          action = 'Lend Request';
          description = status == 'accepted'
              ? 'Lent to $otherUserName'
              : status == 'rejected'
              ? 'Rejected to lend to $otherUserName'
              : '$otherUserName wants to borrow';
          break;
        case 'sell':
          icon = Icons.attach_money;
          color = Colors.orange;
          action = 'Sale Request';
          description = status == 'accepted'
              ? 'Sold to $otherUserName'
              : status == 'rejected'
              ? 'Rejected to sell to $otherUserName'
              : '$otherUserName wants to buy';
          break;
        case 'swap':
          icon = Icons.swap_horiz;
          color = Colors.purple;
          action = 'Swap Request';
          description = status == 'accepted'
              ? 'Swapped with $otherUserName'
              : status == 'rejected'
              ? 'Rejected to swap with $otherUserName'
              : '$otherUserName wants to swap';
          break;
        default:
          icon = Icons.help;
          color = Colors.grey;
          action = 'Request';
          description = 'Transaction with $otherUserName';
      }
    }

    Color statusColor = (status == 'accepted' || status == 'completed')
        ? Colors.green
        : status == 'rejected'
        ? Colors.red
        : Colors.orange;

    String statusText;
    if (status == 'completed') {
      statusText = 'COMPLETED';
    } else if (status == 'accepted') {
      if (type == 'borrow' && role == 'provider') {
        statusText = 'LENT';
      } else if (type == 'borrow' && role == 'requester') {
        statusText = 'BORROWED';
      } else if (type == 'sell' && role == 'provider') {
        statusText = 'SOLD';
      } else if (type == 'sell' && role == 'requester') {
        statusText = 'BOUGHT';
      } else if (type == 'swap') {
        statusText = 'SWAPPED';
      } else {
        statusText = 'ACCEPTED';
      }
    } else if (status == 'rejected') {
      statusText = 'REJECTED';
    } else {
      statusText = 'PENDING';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          action,
                          style: TextStyle(
                            fontSize: 14,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      itemTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status != 'completed') ...[
            if (amount != null || deadline != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (amount != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.attach_money,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Amount: ₱${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (deadline != null && amount != null)
                      const SizedBox(height: 8),
                    if (deadline != null && status == 'accepted') ...[
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: DateTime.now().isAfter(deadline.toDate())
                                ? Colors.red
                                : Colors.purple,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Deadline: ${DateFormat('MMM d, yyyy').format(deadline.toDate())}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: DateTime.now().isAfter(deadline.toDate())
                                  ? Colors.red
                                  : Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
          if (status == 'completed') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      type == 'borrow'
                          ? 'Item returned successfully'
                          : 'Transaction completed successfully',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (timestamp != null) ...[
            const SizedBox(height: 12),
            Text(
              _formatTimestamp(timestamp.toDate()),
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBorrowTransactionCard(Map<String, dynamic> transaction) {
    final status = transaction['status'] ?? 'pending';
    final itemTitle = transaction['itemTitle'] ?? 'Unknown Item';
    final timestamp = transaction['createdAt'] as Timestamp?;
    final otherUserName = transaction['otherUserName'] ?? 'Unknown User';
    final deadline = transaction['deadline'] as Timestamp?;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        statusText = 'BORROWED';
        statusIcon = Icons.check_circle;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = 'COMPLETED';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'REJECTED';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'PENDING';
        statusIcon = Icons.access_time;
    }

    bool isOverdue = false;
    if (status == 'accepted' && deadline != null) {
      isOverdue = DateTime.now().isAfter(deadline.toDate());
      if (isOverdue) {
        statusColor = Colors.red;
        statusText = 'Overdue';
        statusIcon = Icons.warning;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.download,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'from $otherUserName',
                      style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      statusText.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (status != 'completed') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          status == 'accepted'
                              ? 'Your borrow request was approved'
                              : status == 'rejected'
                              ? 'Your borrow request was rejected'
                              : 'Waiting for owner\'s response',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (deadline != null && status == 'accepted') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: isOverdue ? Colors.red : Colors.purple,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Return by: ${DateFormat('MMM d, yyyy').format(deadline.toDate())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue ? Colors.red : Colors.purple,
                            fontWeight: isOverdue
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (status == 'completed') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Item returned successfully',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (timestamp != null) ...[
            const SizedBox(height: 8),
            Text(
              'Requested: ${_formatTimestamp(timestamp.toDate())}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSoldTransactionCard(Map<String, dynamic> transaction) {
    final status = transaction['status'] ?? 'pending';
    final itemTitle = transaction['itemTitle'] ?? 'Unknown Item';
    final amount = transaction['amount'] as double?;
    final otherUserName = transaction['otherUserName'] ?? 'Unknown Buyer';
    final timestamp = transaction['createdAt'] as Timestamp?;
    final role = transaction['role'] ?? '';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        statusText = role == 'provider' ? 'SOLD' : 'BOUGHT';
        statusIcon = Icons.check_circle;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = 'COMPLETED';
        statusIcon = Icons.done_all;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'REJECTED';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'PENDING';
        statusIcon = Icons.access_time;
    }

    final isProvider = role == 'provider';
    final description = isProvider
        ? (status == 'accepted'
              ? 'Sold to $otherUserName'
              : status == 'rejected'
              ? 'Rejected sale to $otherUserName'
              : '$otherUserName wants to buy')
        : (status == 'accepted'
              ? 'Bought from $otherUserName'
              : status == 'rejected'
              ? 'Purchase rejected by $otherUserName'
              : 'Requested to buy from $otherUserName');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.attach_money,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isProvider ? 'Sale Request' : 'Purchase Request',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                statusText.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      itemTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              if (amount != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₱${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          if (timestamp != null) ...[
            const SizedBox(height: 12),
            Text(
              'Requested: ${_formatTimestamp(timestamp.toDate())}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSwapTransactionCard(Map<String, dynamic> transaction) {
    final status = transaction['status'] ?? 'pending';
    final role = transaction['role'] ?? '';
    final itemTitle = transaction['itemTitle'] ?? 'Unknown Item';
    final timestamp = transaction['createdAt'] as Timestamp?;
    final otherUserName = transaction['otherUserName'] ?? 'Unknown User';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        statusText = 'SWAPPED';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'REJECTED';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'PENDING';
        statusIcon = Icons.access_time;
    }

    final isRequester = role == 'requester';
    final color = isRequester ? Colors.blue : Colors.purple;
    final swapDescription = isRequester
        ? (status == 'accepted'
              ? 'Swapped with $otherUserName'
              : status == 'rejected'
              ? 'Swap rejected by $otherUserName'
              : 'Requested to swap with $otherUserName')
        : (status == 'accepted'
              ? 'Swapped with $otherUserName'
              : status == 'rejected'
              ? 'Rejected swap request from $otherUserName'
              : '$otherUserName wants to swap');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.swap_horiz, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Swap ${isRequester ? 'Request' : 'Offer'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                statusText.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      itemTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      swapDescription,
                      style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status == 'accepted'
                        ? 'Swap completed successfully'
                        : status == 'rejected'
                        ? 'Swap request was rejected'
                        : isRequester
                        ? 'Waiting for owner\'s response'
                        : 'You can accept or reject this swap',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
          ),
          if (timestamp != null) ...[
            const SizedBox(height: 8),
            Text(
              'Requested: ${_formatTimestamp(timestamp.toDate())}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600] : Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transactions will appear here',
            style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Error loading transactions'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    return DateFormat('MM/dd/yyyy h:mm a').format(dateTime);
  }
}
