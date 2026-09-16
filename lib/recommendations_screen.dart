import 'dart:ui';
import 'package:flutter/material.dart';

class RecommendationsScreen extends StatelessWidget {
  final List<dynamic> recommendations;
  final String prompt;
  final VoidCallback onClose;

  const RecommendationsScreen({
    super.key,
    required this.recommendations,
    required this.prompt,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    final topMatch = recommendations[0];
    final otherMatches = recommendations.length > 1 ? recommendations.sublist(1) : [];

    return Positioned.fill(
      child: Container(
        color: const Color(0xFF05060B), // Deepest dark background from CSS
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF12172A),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.07),
                          ),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF8B93A9),
                            size: 20,
                          ),
                          onPressed: onClose,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your matches',
                              style: TextStyle(
                                color: Color(0xFFF2F3F8),
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '"$prompt"',
                              style: const TextStyle(
                                color: Color(0xFF8B93A9),
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // --- HERO CARD (TOP MATCH) ---
                  _HeroMatchCard(item: topMatch),

                  const SizedBox(height: 22),

                  // --- COMPACT LIST (OTHER MATCHES) ---
                  if (otherMatches.isNotEmpty)
                    Column(
                      children: otherMatches
                          .map((item) => _CompactMatchCard(
                                item: item,
                                isLast: item == otherMatches.last,
                              ))
                          .toList(),
                    ),
                    
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// HERO MATCH CARD (INDEX 0)
// ==========================================
class _HeroMatchCard extends StatefulWidget {
  final dynamic item;

  const _HeroMatchCard({required this.item});

  @override
  State<_HeroMatchCard> createState() => _HeroMatchCardState();
}

class _HeroMatchCardState extends State<_HeroMatchCard> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final parsed = _parsePerfumeData(widget.item);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171D33), // --surface-2
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Stack(
        children: [
          // Radial Gradient Background (Top Right)
          Positioned(
            top: -50,
            right: -50,
            width: 250,
            height: 250,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD98A44).withOpacity(0.18),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          
          // Card Content
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Right Badge
                const Align(
                  alignment: Alignment.topRight,
                  child: Text(
                    'Top match',
                    style: TextStyle(
                      color: Color(0xFFD98A44),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                
                // Swatch
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFD98A44), Color(0xFF8A4A22)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8A4A22).withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                
                // Text Info
                Text(
                  parsed.brandName,
                  style: const TextStyle(
                    color: Color(0xFF7C6FEA), // --accent
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  parsed.name,
                  style: const TextStyle(
                    color: Color(0xFFF2F3F8),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  parsed.contextNotes.isNotEmpty 
                      ? parsed.contextNotes.first 
                      : 'A perfect match for your specific preferences and environment.',
                  style: const TextStyle(
                    color: Color(0xFF8B93A9),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Linear Progress Meter
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: parsed.score / 100,
                          minHeight: 6,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C6FEA)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${parsed.score.round()}% match',
                      style: const TextStyle(
                        color: Color(0xFFF2F3F8),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // Handle Add to Library (To be implemented)
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C6FEA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF7C6FEA)),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Add to library',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showDetails = !_showDetails),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.14)),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Why this match',
                            style: TextStyle(
                              color: Color(0xFFF2F3F8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Expanded Details (Same as list view)
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  child: _showDetails ? _buildExpandedDetails(parsed) : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// COMPACT MATCH CARD (LIST ITEMS)
// ==========================================
class _CompactMatchCard extends StatefulWidget {
  final dynamic item;
  final bool isLast;

  const _CompactMatchCard({required this.item, required this.isLast});

  @override
  State<_CompactMatchCard> createState() => _CompactMatchCardState();
}

class _CompactMatchCardState extends State<_CompactMatchCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final parsed = _parsePerfumeData(widget.item);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
      decoration: BoxDecoration(
        border: widget.isLast ? null : Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Row
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Swatch Mini
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _getSwatchColors(parsed.name),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info Middle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parsed.brandName,
                        style: const TextStyle(
                          color: Color(0xFF7C6FEA),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        parsed.name,
                        style: const TextStyle(
                          color: Color(0xFFF2F3F8),
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: parsed.chips.map((chip) => Padding(
                          padding: const EdgeInsets.only(right: 5.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.07)),
                            ),
                            child: Text(
                              chip,
                              style: const TextStyle(
                                color: Color(0xFF5C6377), // --text-faint
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                ),

                // Score Right
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${parsed.score.round()}',
                      style: const TextStyle(
                        color: Color(0xFFF2F3F8),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'match',
                      style: TextStyle(
                        color: Color(0xFF5C6377),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Details Toggle Row
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isExpanded ? 'Hide details' : 'Show details',
                    style: const TextStyle(
                      color: Color(0xFF8B93A9),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFF8B93A9),
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Detail Body
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: _isExpanded ? _buildExpandedDetails(parsed) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SHARED WIDGETS & LOGIC
// ==========================================

Widget _buildExpandedDetails(_ParsedPerfumeData parsed) {
  return Padding(
    padding: const EdgeInsets.only(top: 10.0, left: 4.0, right: 4.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parsed.likedNotes.isNotEmpty || parsed.likedAccords.isNotEmpty) ...[
          const Text(
            'Because of what you love',
            style: TextStyle(
              color: Color(0xFF5C6377),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...parsed.likedNotes.map((note) => _buildPill(note, isNote: true)),
              ...parsed.likedAccords.map((accord) => _buildPill(accord, isNote: false)),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        if (parsed.contextNotes.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.025),
              borderRadius: BorderRadius.circular(4),
              border: const Border(
                left: BorderSide(color: Color(0xFF242A3D), width: 2), // --border-strong
              ),
            ),
            child: Text(
              parsed.contextNotes.join(' '),
              style: const TextStyle(
                color: Color(0xFF8B93A9),
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _buildPill(String text, {required bool isNote}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: isNote ? const Color(0xFFE8779C).withOpacity(0.14) : const Color(0xFF7C6FEA).withOpacity(0.16),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isNote ? Icons.favorite : Icons.auto_awesome,
          size: 10,
          color: isNote ? const Color(0xFFE8779C) : const Color(0xFFB3A8FF),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: isNote ? const Color(0xFFE8779C) : const Color(0xFFB3A8FF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// Generate consistent gradient swatches based on perfume name
List<Color> _getSwatchColors(String name) {
  final palettes = [
    [const Color(0xFFC17A3E), const Color(0xFF6B3A1F)],
    [const Color(0xFF8B5E34), const Color(0xFF3D2818)],
    [const Color(0xFFB8752F), const Color(0xFF7A3E1F)],
    [const Color(0xFFA6602F), const Color(0xFF4A2814)],
    [const Color(0xFFC68A4E), const Color(0xFF6B3A1F)],
  ];
  int hash = name.hashCode.abs();
  return palettes[hash % palettes.length];
}

class _ParsedPerfumeData {
  final String brandName;
  final String name;
  final double score;
  final List<String> likedNotes;
  final List<String> likedAccords;
  final List<String> contextNotes;
  final List<String> chips;

  _ParsedPerfumeData({
    required this.brandName,
    required this.name,
    required this.score,
    required this.likedNotes,
    required this.likedAccords,
    required this.contextNotes,
    required this.chips,
  });
}

_ParsedPerfumeData _parsePerfumeData(dynamic item) {
  final String brandName = item['brandName'] ?? 'Unknown';
  final String name = item['name'] ?? 'Unknown';
  final double score = (item['finalScore'] as num?)?.toDouble() ?? 0.0;
  
  final List<String> rawReasons = List<String>.from(item['explanationReasons'] ?? []);
  
  List<String> notes = [];
  List<String> accords = [];
  List<String> context = [];
  List<String> chips = [];

  for (String r in rawReasons) {
    if (r.toLowerCase().contains('liked note:')) {
      final note = r.split(':').last.trim();
      notes.add(note);
      if (chips.length < 2) chips.add(note);
    } else if (r.toLowerCase().contains('preferred accord:')) {
      final accord = r.split(':').last.trim();
      accords.add(accord);
      if (chips.length < 2) chips.add(accord);
    } else {
      // Capitalize first letter and add period for sentences
      if (r.isNotEmpty) {
        String formatted = r[0].toUpperCase() + r.substring(1);
        if (!formatted.endsWith('.')) formatted += '.';
        context.add(formatted);
      }
    }
  }

  return _ParsedPerfumeData(
    brandName: brandName,
    name: name,
    score: score,
    likedNotes: notes,
    likedAccords: accords,
    contextNotes: context,
    chips: chips,
  );
}