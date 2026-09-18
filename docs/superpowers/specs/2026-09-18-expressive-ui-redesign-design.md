# Flui Expressive UI Redesign

## Product direction

Flui will feel like a living communication gym: energetic, tactile and premium without becoming childish or visually noisy. The visual metaphor is **ideas becoming voice**. Cards represent thoughts the user can organize; a responsive voice orb represents speech becoming visible.

The redesign takes three useful ideas from the supplied references without copying their branding:

- stacked cards that preserve spatial continuity between screens;
- bold editorial type paired with bright, bounded color fields;
- a soft, liquid focal object that reacts to touch and microphone energy.

## Visual identity

The base remains warm and readable, but the former cream-and-green system expands into a distinctive communication palette:

- Ink `#151426`: primary text and premium dark surfaces.
- Paper `#FFF9F2`: main background.
- Electric blue `#536DFF`: voice, action and active navigation.
- Aqua `#46D9D0`: clarity and fluency.
- Coral `#FF6B61`: energy and speaking challenges.
- Acid lime `#D9FF57`: progress and success.
- Soft pink `#FFD6EA`: vocabulary and storytelling.
- Lavender `#B8A7FF`: reflection and coaching.

Color is assigned by skill, not randomly. Text always uses verified high-contrast foregrounds. Gradients are limited to the voice orb and ambient background accents.

Plus Jakarta Sans remains the display family and Inter remains the reading family. Display hierarchy becomes larger and tighter; long coaching text stays calm and highly readable.

## Shape and surfaces

Cards use asymmetric corner radii and colored layers to resemble presenter cue cards. Important cards may expose the edge of the next card, making progression visible. Flat white cards are replaced with colored skill surfaces, dark anchor cards and light paper cards with strong borders.

The bottom navigation becomes a compact floating dock. The selected destination expands subtly and carries a color field; inactive destinations stay quiet.

## Motion language

Motion communicates continuity:

- entering sections use short staggered rises;
- card changes use shared-axis slide and scale rather than fades;
- taps compress and rebound within 180–260 ms;
- stacked cards fan or advance in the direction of navigation;
- the voice orb breathes softly while idle, reacts to microphone amplitude while recording and tightens into a focused pulse while analysis runs.

Motion never blocks interaction. `MediaQuery.disableAnimations` produces a static equivalent, and information is never communicated by animation alone.

## Speaking experience

The 45-second challenge becomes the visual flagship:

1. Ready: prompt card, duration chip and a luminous voice orb.
2. Recording: orb deformation and concentric color layers respond to live amplitude; countdown remains readable.
3. Cue cards: three optional presenter cards — opening, key idea and closing — can be revealed without stopping the recording. They guide structure but never provide a full script.
4. Analysis: the orb compresses into a listening pulse while the UI explains the current step.
5. Feedback: transcript and coaching appear as a sequenced card stack, with measured signals visually separated from AI estimates.

## Main surfaces

- Today becomes a colorful training dashboard with an oversized oral-training hero, layered session cards and compact progress tiles.
- Words uses collectible vocabulary cards with state colors.
- Progress uses a dark editorial canvas with bright metric cards.
- Onboarding and authentication inherit the palette, typography, buttons and ambient shapes without adding unnecessary steps.

## Media

Original abstract imagery may be generated for contextual cards. Images must support storytelling or scenario recognition, never act as decoration behind essential text. The core voice orb is code-native for responsiveness and performance.

## Technical boundaries

- Flutter and existing Material/Riverpod/navigation architecture remain.
- Prefer code-native animation and CustomPainter for the interactive orb.
- Add no paid runtime service for visual effects.
- Keep 44 px minimum targets, semantic labels and 130% text-scale compatibility.
- Existing domain flows, authentication, speech analysis and data contracts remain intact.
- Every new reusable component receives widget or unit coverage.

## Success criteria

- A user recognizes the speaking action in under two seconds.
- Recording visibly responds to microphone energy.
- Cue cards are usable during a recording without obscuring the countdown or stop action.
- Screen changes feel spatially connected.
- The main three tabs share one visual language while retaining distinct skill colors.
- Reduced-motion mode is complete and functional.
- Existing automated tests continue to pass.
