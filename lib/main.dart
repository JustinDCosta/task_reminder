import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

void main() async {
  // We will add Firebase setup here in the next step
  WidgetsFlutterBinding.ensureInitialized();
  
  // This is the line that connects to the cloud!
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Reminder',
      debugShowCheckedModeBanner: false, // Hides the 'Debug' banner
      
      // 1. LIGHT THEME CONFIG
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blue, 
        textTheme: GoogleFonts.poppinsTextTheme(), // Modern Google Font
      ),

      // 2. DARK THEME CONFIG
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),

      // 3. AUTO-SWITCH SETTING
      themeMode: ThemeMode.system, 

      // This "StreamBuilder" listens to Firebase in real-time.
      // If the user logs in or out, it instantly switches the screen!
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const HomePage(); // User is logged in!
          }
          return const LoginPage(); // User needs to log in.
        },
      ),
    );
  }
}

// Your Home Screen
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 1. GET THE CURRENT USER
  final User? user = FirebaseAuth.instance.currentUser;

  // 2. FUNCTION TO ADD OR EDIT A TASK
  void _showTaskDialog({DocumentSnapshot? taskToEdit}) {
    final titleController = TextEditingController(
      text: taskToEdit != null ? taskToEdit['title'] : ''
    );
    // If editing, use existing date, else null
    DateTime? selectedDate = taskToEdit != null && taskToEdit['deadline'] != null 
        ? DateTime.parse(taskToEdit['deadline']) 
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: taskToEdit == null ? 'New Task' : 'Edit Task',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            
            // Date Picker
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(selectedDate == null 
                        ? "Select Deadline" 
                        : DateFormat.yMMMd().format(selectedDate!)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        selectedDate = picked;
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Save/Update Button
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;

                if (taskToEdit == null) {
                  // CREATE NEW TASK
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .collection('tasks')
                      .add({
                        'title': titleController.text.trim(),
                        'deadline': selectedDate?.toIso8601String(),
                        'isDone': false,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                  
                  // Schedule Notification
                  if (selectedDate != null) {
                     int uniqueId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
                     await NotificationService().scheduleNotification(
                        uniqueId, titleController.text.trim(), selectedDate!);
                  }

                } else {
                  // UPDATE EXISTING TASK
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .collection('tasks')
                      .doc(taskToEdit.id)
                      .update({
                        'title': titleController.text.trim(),
                        'deadline': selectedDate?.toIso8601String(),
                      });
                   // (Optional: You could cancel old notification and schedule new one here)
                }

                if (mounted) Navigator.pop(context);
              },
              child: Text(taskToEdit == null ? "Add Task" : "Save Changes"),
            )
          ],
        ),
      ),
    );
  }

  // 3. FUNCTION TO TOGGLE "DONE" STATUS
  void _toggleTask(String taskId, bool currentStatus) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('tasks')
        .doc(taskId)
        .update({'isDone': !currentStatus});
  }

  // 4. FUNCTION TO DELETE
  void _deleteTask(String taskId) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Tasks"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      
      // THE LIVE DATA STREAM
      body: StreamBuilder(
        // Listen to the user's specific task collection
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('tasks')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        
        builder: (context, snapshot) {
          // Handling different states
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No tasks yet. Add one!"));
          }

          // Display the list
          final tasks = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final data = task.data();
              final String id = task.id;
              final bool isDone = data['isDone'] ?? false;
              
              // Formatting the date (if one exists)
              String? formattedDate;
              if (data['deadline'] != null) {
                final date = DateTime.parse(data['deadline']);
                formattedDate = DateFormat.yMMMd().format(date);
              }

              return Dismissible(
                key: Key(id),
                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (direction) => _deleteTask(id), // Swipe to delete
                child: ListTile(
                  onTap: () => _showTaskDialog(taskToEdit: task),

                  leading: Checkbox(
                    value: isDone,
                    onChanged: (val) => _toggleTask(id, isDone),
                  ),
                  title: Text(
                    data['title'],
                    style: TextStyle(
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? Colors.grey : null,
                    ),
                  ),
                  subtitle: formattedDate != null 
                      ? Text("Deadline: $formattedDate", style: const TextStyle(color: Colors.blue)) 
                      : null,
                ),
              );
            },
          );
        },
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(), // No arguments = Add Mode
        child: const Icon(Icons.add),
      ),
    );
  }
}