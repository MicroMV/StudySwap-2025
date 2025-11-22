const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Run every day at 9:00 AM Philippine Time
exports.checkBorrowDeadlines = onSchedule(
    {
      schedule: "0 9 * * *",
      timeZone: "Asia/Manila",
    },
    async (event) => {
      try {
        const firestore = admin.firestore();
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);

        logger.info("Checking borrow deadlines for today...", {
          date: today.toISOString(),
        });

        // Query items with borrowDeadline today
        const itemsSnapshot = await firestore
            .collection("items")
            .where("isBorrowed", "==", true)
            .where(
                "borrowDeadline",
                ">=",
                admin.firestore.Timestamp.fromDate(today),
            )
            .where(
                "borrowDeadline",
                "<",
                admin.firestore.Timestamp.fromDate(tomorrow),
            )
            .get();

        logger.info(
            `Found ${itemsSnapshot.size} items with deadline today`,
        );

        const notificationPromises = [];

        for (const doc of itemsSnapshot.docs) {
          const item = doc.data();
          const itemId = doc.id;
          const ownerId = item.userId;
          const borrowerId = item.completedWith;
          const borrowerName = item.userName || "Borrower";

          if (!borrowerId) {
            logger.warn(
                `Item ${itemId} has no borrower assigned`,
            );
            continue;
          }

          // Notification for LENDER (owner)
          const lenderNotification = {
            userId: ownerId,
            title: "⏰ Borrow Deadline Today",
            body:
              `"${item.title}" should be returned by ` +
              `${borrowerName} today`,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false,
            data: {
              type: "deadline_reminder",
              itemId: itemId,
              itemTitle: item.title,
              role: "lender",
              borrowerId: borrowerId,
            },
          };

          // Notification for BORROWER
          const borrowerNotification = {
            userId: borrowerId,
            title: "⏰ Return Reminder",
            body:
              `Please return "${item.title}" to the owner today`,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false,
            data: {
              type: "deadline_reminder",
              itemId: itemId,
              itemTitle: item.title,
              role: "borrower",
              ownerId: ownerId,
            },
          };

          // Add both notifications
          notificationPromises.push(
              firestore
                  .collection("notifications")
                  .add(lenderNotification),
              firestore
                  .collection("notifications")
                  .add(borrowerNotification),
          );

          logger.info(
              `Created deadline notifications for: ${item.title}`,
          );
        }

        await Promise.all(notificationPromises);
        logger.info(
            `Successfully sent ${notificationPromises.length} ` +
            `deadline notifications`,
        );

        return null;
      } catch (error) {
        logger.error("Error checking deadlines:", error);
        return null;
      }
    },
);
