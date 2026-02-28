const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendOrderStatusNotification = functions.firestore
  .document("orders/{orderId}")
  .onUpdate((change, context) => {
    const newValue = change.after.data();
    const previousValue = change.before.data();

    // Only send a notification if the status has changed
    if (newValue.status === previousValue.status) {
      return null;
    }

    const orderId = context.params.orderId;
    const userId = newValue.userId;
    const status = newValue.status;

    let title, body;

    switch (status) {
      case "preparing":
        title = "Order Update";
        body = "Good news! We're now preparing your order.";
        break;
      case "ready":
        title = "Order Ready!";
        body = "Your order is ready for pickup. Come get it!";
        break;
      case "completed":
        // You might not want to send a notification for completed orders
        return null;
      default:
        return null;
    }

    // Get the user's device token
    return admin.firestore().collection('users').doc(userId).get()
      .then(userDoc => {
        const deviceToken = userDoc.data().deviceToken;
        if (!deviceToken) {
          console.log('No device token for user:', userId);
          return null;
        }

        // Construct the message payload
        const message = {
          notification: { title: title, body: body },
          data: { orderId: orderId }, // Send orderId for deep linking
          token: deviceToken,
        };

        // Send the message
        return admin.messaging().send(message)
          .then(response => {
            console.log('Successfully sent message:', response);
          })
          .catchError(error => {
            console.log('Error sending message:', error);
          });
      });
  });