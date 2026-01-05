import 'package:flutter/material.dart';
import 'package:legacy_pert_chart/legacy_pert_chart.dart';
import 'package:legacy_gantt_chart/legacy_gantt_chart.dart';
import 'package:provider/provider.dart';
import 'pert_view_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PertViewModel(),
      child: MaterialApp(
        title: 'Legacy PERT Chart Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: ThemeMode.system,
        home: const PertChartPage(),
      ),
    );
  }
}

class PertChartPage extends StatefulWidget {
  const PertChartPage({super.key});

  @override
  State<PertChartPage> createState() => _PertChartPageState();
}

class _PertChartPageState extends State<PertChartPage> {
  final TextEditingController _uriController = TextEditingController(
    text: 'https://api.gantt-sync.com',
  );
  final TextEditingController _tenantController = TextEditingController(
    text: 'legacy',
  );
  final TextEditingController _userController = TextEditingController(
    text: 'patrick',
  );
  final TextEditingController _passController = TextEditingController(
    text: 'password',
  );

  bool _isPanelVisible = true;

  double _controlPanelWidth = 350.0;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PertViewModel>();
    final tasks = viewModel.tasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Legacy PERT Chart Example'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => setState(() => _isPanelVisible = !_isPanelVisible),
        ),
      ),
      body: Row(
        children: [
          if (_isPanelVisible)
            SizedBox(
              width: _controlPanelWidth,
              child: _buildControlPanel(context, viewModel),
            ),
          if (_isPanelVisible)
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _controlPanelWidth = (_controlPanelWidth + details.delta.dx)
                      .clamp(200.0, 600.0);
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: VerticalDivider(
                  width: 8,
                  thickness: 1,
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
          Expanded(
            child: viewModel.isConnected && tasks.isEmpty
                ? const Center(child: Text("Waiting for data..."))
                : LegacyPertChartWidget(
                    tasks: tasks.isEmpty ? _getSampleTasks() : tasks,
                    nodeBuilder: (context, task, size) {
                      if (task.name == 'Custom Node') {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.star, color: Colors.white),
                        );
                      }
                      return null;
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context, PertViewModel viewModel) {
    return Container(
      color: Theme.of(context).cardColor,
      child: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          Text('Server Sync', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (viewModel.isConnected)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Connected',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  StreamBuilder<int>(
                    stream: viewModel.outboundPendingCount,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.upload_file,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pending Outbound: $count',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  StreamBuilder<SyncProgress>(
                    stream: viewModel.inboundProgress,
                    builder: (context, snapshot) {
                      final progress = snapshot.data;
                      if (progress == null ||
                          progress.total == 0 ||
                          (progress.processed >= progress.total &&
                              progress.total > 0)) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Syncing: ${progress.processed} / ${progress.total}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(value: progress.percentage),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => viewModel.disconnect(),
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _uriController,
                  decoration: const InputDecoration(
                    labelText: 'Server URI',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tenantController,
                  decoration: const InputDecoration(
                    labelText: 'Tenant ID',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _userController,
                        decoration: const InputDecoration(
                          labelText: 'User',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _passController,
                        decoration: const InputDecoration(
                          labelText: 'Pass',
                          isDense: true,
                        ),
                        obscureText: true,
                      ),
                    ),
                  ],
                ),
                if (viewModel.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      viewModel.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    viewModel.connect(
                      uri: _uriController.text,
                      tenantId: _tenantController.text,
                      username: _userController.text,
                      password: _passController.text,
                    );
                  },
                  child: const Text('Connect'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<LegacyPertTask> _getSampleTasks() {
    return [
      const LegacyPertTask(id: '1', name: 'Start'),
      const LegacyPertTask(id: '2', name: 'Task A', dependencyIds: ['1']),
      const LegacyPertTask(id: '3', name: 'Task B', dependencyIds: ['1']),
      const LegacyPertTask(
        id: '4',
        name: 'Custom Node',
        dependencyIds: ['2', '3'],
      ),
      const LegacyPertTask(id: '5', name: 'End', dependencyIds: ['4']),
    ];
  }
}
