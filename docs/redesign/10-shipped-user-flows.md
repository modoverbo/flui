# Shipped User Flows

This document is the current route and interaction reference for the editorial redesign. The older `00`–`09` documents preserve pre-redesign inventory, design exploration, and rationale; they are historical, not implementation instructions. The approved flow is recorded in Engram observation `design/app-redesign/written-spec` (#62).

## Browse published vocabulary

1. **Inicio** shows five directly navigable category cards, one for each existing `ThemeFamily`: Trabajo, Social, Público, Precisión, and Emoción.
2. Selecting a category opens its published-word catalog at `/today/categories/:family`.
3. The catalog shows the category's published words, deduplicated by word ID. `Todos` is the default; a theme filter is optional and narrows only that category's list. There is no required intermediate theme-selection screen.
4. A word card opens the existing `/words/:wordId` detail route. Returning restores the category, selected filter, and scroll position.

A word associated with themes in more than one family can appear once in each matching category. Publication eligibility comes from the catalog provider; the family projection groups the catalog it receives and does not independently decide publication status.

## Keep the Words tab as repertoire

The **Palabras** tab at `/words` remains the user's introduced repertoire, backed by `myWordsProvider` and filterable by learning state. It is not the new published-word catalog. Published words that have not yet been introduced are still available through category browsing and can be opened in word detail; progress-dependent mastery and review information appears only when the user has an entry for that word.

## Speak and receive written feedback

The existing **Habla** challenge remains a separate speaking surface. The user presses and holds the microphone to record; releasing submits the recording once for analysis. Results and coaching are presented as text. The flow does not use TTS or audio playback, and it reuses the existing recorder and analysis contracts.

## Source of truth

| Behavior | Current implementation |
|---|---|
| Four-tab shell and category/deep-link route builders | `app/lib/app/router/app_routes.dart`, `app/lib/app/router/app_router.dart` |
| Five family values | `app/lib/features/themes/domain/theme.dart` |
| Published catalog grouping, optional filter, and back-state parameters | `app/lib/features/vocabulary/presentation/category_catalog_projection.dart`, `category_catalog_page.dart` |
| Words-tab repertoire | `app/lib/features/vocabulary/presentation/providers/my_words.dart`, `words_page.dart` |
| Published-word detail with optional learning entry | `app/lib/features/vocabulary/presentation/word_detail_page.dart` |
| Hold/release recording and submission | `app/lib/features/speaking/presentation/speaking_challenge_page.dart` |
