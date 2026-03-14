import 'package:flutter/material.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      '❓ كيف تلعب؟',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ─── المحتوى ──────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  // ── مرحبا ──────────────────────────────────────────────
                  _buildWelcomeCard(),
                  const SizedBox(height: 20),

                  // ── أوضاع اللعب ────────────────────────────────────────
                  _buildSectionTitle('🎮 أوضاع اللعب'),
                  const SizedBox(height: 10),
                  _buildGameModes(),
                  const SizedBox(height: 20),

                  // ── نظام الأسئلة ───────────────────────────────────────
                  _buildSectionTitle('📚 نظام الأسئلة'),
                  const SizedBox(height: 10),
                  _buildQuestionsSystem(),
                  const SizedBox(height: 20),

                  // ── نظام الدرجات ───────────────────────────────────────
                  _buildSectionTitle('⭐ نظام الدرجات'),
                  const SizedBox(height: 10),
                  _buildScoreSystem(),
                  const SizedBox(height: 20),

                  // ── مستويات الصعوبة ────────────────────────────────────
                  _buildSectionTitle('🔥 مستويات الصعوبة'),
                  const SizedBox(height: 10),
                  _buildDifficultyLevels(),
                  const SizedBox(height: 20),

                  // ── اللعب الثنائي ──────────────────────────────────────
                  _buildSectionTitle('⚔️ اللعب الثنائي'),
                  const SizedBox(height: 10),
                  _buildMultiplayerInfo(),
                  const SizedBox(height: 20),

                  // ── نصائح ─────────────────────────────────────────────
                  _buildSectionTitle('💡 نصائح للفوز'),
                  const SizedBox(height: 10),
                  _buildTips(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── بطاقة الترحيب ───────────────────────────────────────────────────────
  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3D5AF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        children: [
          Text('🎮', style: TextStyle(fontSize: 50)),
          SizedBox(height: 12),
          Text(
            'BeroGames',
            style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'لعبة مسابقات ثقافية تنافسية!\nاختبر معلوماتك وتحدّى أصدقاءك',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── عنوان قسم ───────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) => Row(
        children: [
          Text(
            title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold),
          ),
        ],
      );

  // ─── أوضاع اللعب ─────────────────────────────────────────────────────────
  Widget _buildGameModes() {
    final modes = [
      {
        'icon': '🎯',
        'title': 'لعب فردي',
        'desc': 'العب بمفردك واختبر نفسك في 5 أقسام مختلفة. الأسئلة تتصعب تدريجياً كلما أجبت صح.',
        'color': const Color(0xFF6C63FF),
      },
      {
        'icon': '⚡',
        'title': 'بحث تلقائي',
        'desc': 'يتم إيجاد خصم مناسب لك تلقائياً وتبدأ المسابقة فوراً!',
        'color': const Color(0xFFFFD700),
      },
      {
        'icon': '🏠',
        'title': 'إنشاء غرفة',
        'desc': 'أنشئ غرفة خاصة واشارك الكود مع صديقك للعب معاً.',
        'color': const Color(0xFF9C27B0),
      },
      {
        'icon': '👥',
        'title': 'تحدي الأصدقاء',
        'desc': 'أضف أصدقاءك وابعتلهم دعوة للعب مباشرة من قائمة الأصدقاء.',
        'color': const Color(0xFF43D8C9),
      },
    ];

    return Column(
      children: modes.map((m) => _buildModeCard(
        icon:  m['icon']  as String,
        title: m['title'] as String,
        desc:  m['desc']  as String,
        color: m['color'] as Color,
      )).toList(),
    );
  }

  Widget _buildModeCard({
    required String icon,
    required String title,
    required String desc,
    required Color  color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── نظام الأسئلة ────────────────────────────────────────────────────────
  Widget _buildQuestionsSystem() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          _buildInfoRow('📂', 'الأقسام',
              '5 أقسام: علوم، ثقافة، رياضة، جغرافيا، تاريخ'),
          const Divider(color: Colors.white10),
          _buildInfoRow('⏱️', 'الوقت',
              'كل سؤال له 15 ثانية للإجابة'),
          const Divider(color: Colors.white10),
          _buildInfoRow('🔄', 'الإجابة الخاطئة',
              'تبقى في نفس السؤال وتحاول مجدداً حتى تجيب صح'),
          const Divider(color: Colors.white10),
          _buildInfoRow('⏰', 'انتهاء الوقت',
              'يُعدّ كإجابة خاطئة وتُخصم نقاط'),
          const Divider(color: Colors.white10),
          _buildInfoRow('📈', 'تقدم المستوى',
              'كل إجابتين صح متتاليتين ترفعك لمستوى أصعب'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── نظام الدرجات ─────────────────────────────────────────────────────────
  Widget _buildScoreSystem() {
    return Column(
      children: [
        // جدول النقاط
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              // رأس الجدول
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF6C63FF),
                  borderRadius: BorderRadius.only(
                    topLeft:  Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(
                        child: Text('المستوى',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('✅ إجابة صح',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center)),
                    Expanded(
                        child: Text('❌ إجابة غلط',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center)),
                  ],
                ),
              ),
              // صفوف البيانات
              ...List.generate(10, (i) {
                final level = i + 1;
                final pts   = level * 10;
                final ded   = level * 5;
                Color levelColor;
                if (level <= 3)      levelColor = Colors.greenAccent;
                else if (level <= 6) levelColor = Colors.orangeAccent;
                else                 levelColor = Colors.redAccent;

                return Column(
                  children: [
                    if (i != 0) const Divider(color: Colors.white10, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color:
                                        levelColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: levelColor
                                            .withValues(alpha: 0.5)),
                                  ),
                                  child: Text('$level',
                                      style: TextStyle(
                                          color: levelColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Text('+$pts نقطة',
                                style: const TextStyle(
                                    color: Color(0xFF4CAF50),
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center),
                          ),
                          Expanded(
                            child: Text('-$ded نقطة',
                                style: const TextStyle(
                                    color: Color(0xFFF44336),
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ملاحظة
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          ),
          child: const Row(
            children: [
              Text('💡', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'النقاط لا تقل عن صفر — حتى لو خصم منك كتير!',
                  style: TextStyle(color: Colors.amber, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── مستويات الصعوبة ──────────────────────────────────────────────────────
  Widget _buildDifficultyLevels() {
    final levels = [
      {'range': '1 → 3', 'label': 'سهل 🟢', 'desc': 'أسئلة بسيطة للمبتدئين', 'color': Colors.greenAccent},
      {'range': '4 → 6', 'label': 'متوسط 🟡', 'desc': 'أسئلة متوسطة تحتاج تفكير', 'color': Colors.orangeAccent},
      {'range': '7 → 10', 'label': 'صعب 🔴', 'desc': 'أسئلة صعبة للخبراء', 'color': Colors.redAccent},
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: levels.asMap().entries.map((entry) {
              final i = entry.key;
              final l = entry.value;
              final color = l['color'] as Color;
              return Column(
                children: [
                  if (i != 0) const Divider(color: Colors.white10),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l['range'] as String,
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l['label'] as String,
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              Text(l['desc'] as String,
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.4)),
          ),
          child: const Row(
            children: [
              Text('⬆️', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'كل إجابتين صح متتاليتين → تنتقل للمستوى التالي تلقائياً',
                  style: TextStyle(color: Color(0xFF6C63FF), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── اللعب الثنائي ────────────────────────────────────────────────────────
  Widget _buildMultiplayerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          _buildInfoRow('⚡', 'البحث التلقائي',
              'يتم مطابقتك مع لاعب آخر ينتظر وتبدأ المباراة تلقائياً بنفس القسم والأسئلة'),
          const Divider(color: Colors.white10),
          _buildInfoRow('📡', 'المباراة المباشرة',
              'كل لاعب يرى أسئلته الخاصة ونقاطه تتحدث في الوقت الفعلي على الشاشة'),
          const Divider(color: Colors.white10),
          _buildInfoRow('⏰', 'مدة المباراة',
              'وقت ثابت للمباراة — من يجمع أعلى نقاط عند انتهاء الوقت يفوز'),
          const Divider(color: Colors.white10),
          _buildInfoRow('👑', 'الفائز',
              'يُعلن الفائز بعد انتهاء الوقت بناءً على مجموع النقاط'),
        ],
      ),
    );
  }

  // ─── نصائح ───────────────────────────────────────────────────────────────
  Widget _buildTips() {
    final tips = [
      '🎯 ركّز على الإجابة الصحيحة من أول مرة لتتجنب الخصم',
      '⚡ حاول الإجابة بسرعة خاصة في اللعب الثنائي',
      '📈 كلما رفعت مستواك، كلما زادت نقاطك بشكل أكبر',
      '🔥 الإجابتين الصح المتتاليتين تزيد صعوبة السؤال وتضاعف النقاط',
      '👥 تحدى أصدقاءك لأنه أكثر متعة من اللعب بمفردك!',
      '🏆 العب يومياً لترتقي في قائمة المتصدرين',
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: tips.asMap().entries.map((entry) {
          return Column(
            children: [
              if (entry.key != 0) const Divider(color: Colors.white10, height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.value.substring(0, 2),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.value.substring(2).trim(),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
