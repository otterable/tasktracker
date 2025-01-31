// static\js\main.js, do not remove this line
console.log("Main JS loaded.");

function showNotification(title, body) {
  if (Notification.permission === 'granted') {
    new Notification(title, { body: body });
  }
}

// Example usage: showNotification("New Task Assigned", "You have a new task due in 48 hours.");
