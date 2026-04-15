import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import 'widgets/message_bubble.dart';
import 'widgets/chat_input.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  // Mock data - Conversación inicial
  final List<Map<String, dynamic>> _initialMessages = [
    {
      'id': '1',
      'text': 'Hi Alex! Thanks for reaching out. I\'m Sarah from TechCorp\'s HR team.',
      'isMe': false,
      'timestamp': '2024-01-22T14:30:00',
      'senderName': 'Sarah Jenkins',
      'senderRole': 'HR Manager at TechCorp',
      'avatar': '👩‍💼',
    },
    {
      'id': '2',
      'text': 'I noticed you applied for the Software Engineer Intern position. While we decided to move forward with another candidate, I\'d love to give you some feedback.',
      'isMe': false,
      'timestamp': '2024-01-22T14:31:00',
      'senderName': 'Sarah Jenkins',
      'senderRole': 'HR Manager at TechCorp',
      'avatar': '👩‍💼',
    },
    {
      'id': '3',
      'text': 'Thank you so much! I really appreciate the opportunity to learn from this experience.',
      'isMe': true,
      'timestamp': '2024-01-22T14:35:00',
    },
    {
      'id': '4',
      'text': 'Your portfolio was impressive! However, for the Jr. position, we were looking for more hands-on experience with React and Node.js. I\'d suggest building a couple of full-stack projects to strengthen your profile.',
      'isMe': false,
      'timestamp': '2024-01-22T14:38:00',
      'senderName': 'Sarah Jenkins',
      'senderRole': 'HR Manager at TechCorp',
      'avatar': '👩‍💼',
    },
    {
      'id': '5',
      'text': 'That\'s really helpful feedback. Are there any specific project ideas you\'d recommend?',
      'isMe': true,
      'timestamp': '2024-01-22T14:40:00',
    },
  ];

  @override
  void initState() {
    super.initState();
    _messages.addAll(_initialMessages);
    // Scroll to bottom after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final newMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'text': text.trim(),
      'isMe': true,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.add(newMessage);
      _messageController.clear();
    });

    _scrollToBottom();

    // Simular respuesta automática después de 2 segundos
    Future.delayed(const Duration(seconds: 2), () {
      _simulateResponse();
    });
  }

  void _simulateResponse() {
    final responses = [
      'That\'s a great question! I\'d suggest starting with a project that solves a real problem.',
      'For full-stack projects, try building something like a task manager or a social media clone.',
      'Also, make sure to document your code well and deploy it so recruiters can see it live!',
      'Feel free to reach out if you need more guidance. Good luck with your job search!',
    ];

    final randomResponse = responses[_messages.length % responses.length];

    setState(() {
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': randomResponse,
        'isMe': false,
        'timestamp': DateTime.now().toIso8601String(),
        'senderName': 'Sarah Jenkins',
        'senderRole': 'HR Manager at TechCorp',
        'avatar': '👩‍💼',
      });
    });

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primaryPurpleLight,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '👩‍💼',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sarah Jenkins',
                    style: AppTextStyles.subtitle1.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'HR Manager at TechCorp',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showChatOptions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          _buildInfoBanner(),

          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final showAvatar = !message['isMe'] &&
                          (index == 0 ||
                              _messages[index - 1]['isMe'] == true);

                      return MessageBubble(
                        message: message,
                        showAvatar: showAvatar,
                      );
                    },
                  ),
          ),

          // Input field
          ChatInput(
            controller: _messageController,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: AppColors.accentBlue.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.accentBlue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Career Orientation Chat - Get feedback and advice',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.accentBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryPurpleLight.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 50,
                color: AppColors.primaryPurple,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Start the conversation',
              style: AppTextStyles.h4,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask for career advice, interview tips, or feedback on your profile',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickReply('How can I improve my resume?'),
                _buildQuickReply('Tips for technical interviews'),
                _buildQuickReply('What skills should I focus on?'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReply(String text) {
    return InkWell(
      onTap: () => _sendMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceGray,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.borderLight,
          ),
        ),
        child: Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Conversation Info'),
                onTap: () {
                  Navigator.pop(context);
                  _showConversationInfo();
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Export Chat'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Exportar chat
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: AppColors.error),
                title: const Text(
                  'Block Contact',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Bloquear contacto
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showConversationInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conversation Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Contact', 'Sarah Jenkins'),
            const SizedBox(height: 12),
            _buildInfoRow('Company', 'TechCorp Inc.'),
            const SizedBox(height: 12),
            _buildInfoRow('Position', 'HR Manager'),
            const SizedBox(height: 12),
            _buildInfoRow('Messages', '${_messages.length}'),
            const SizedBox(height: 12),
            _buildInfoRow('Started', 'Jan 22, 2024'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}