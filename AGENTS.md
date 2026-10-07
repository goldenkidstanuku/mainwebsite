# Anti-AI-Slop and Anti-AI-Code Engineering Rules

### GENERAL ANTI-AI-SLOP + ANTI-AI-CODE RULES

Do not produce a website that looks generic, nor code that looks like it was blindly generated and pasted together. The goal is to produce work that feels **authored, intentional, product-specific, and technically understood**. Never optimize for the appearance of sophistication. Optimize for correctness, coherence, maintainability, performance, and actual user experience.

Avoid statistically common AI design decisions unless they are genuinely appropriate for the product. Do not automatically use oversized hero typography, excessive rounded cards, pill-shaped controls, bento grids, gradient backgrounds, glowing blobs, glassmorphism, excessive blur, noise/grain, floating particles, neon accents, generic icon grids, fake dashboards, decorative browser windows, excessive shadows, or scroll animations simply because they are common in AI-generated websites. Do not rely on predictable section structures such as hero → features → testimonials → pricing → FAQ → CTA unless the information architecture actually requires them. Avoid repetitive layouts where every section consists of a heading, paragraph, and three cards. Do not add decorative UI, fake data, meaningless statistics, badges, testimonials, labels, awards, social proof, or product claims simply to fill space. Never invent information about the product.

Content must drive the design. Every visual element, interaction, animation, component, and piece of copy must have a reason to exist. Prefer strong hierarchy, typography, spacing, composition, contrast, and intentional restraint over stacking visual effects. Use unusual or asymmetrical layouts only when they improve the actual experience, not simply to appear different. Do not make every element visually special. Contrast and hierarchy require things that are allowed to be quiet.

### CODE SHOULD LOOK HUMAN-ENGINEERED

Code must be treated with the same level of intentionality as the visual design. Do not generate code simply because code is expected. Every abstraction should solve a real problem. Every dependency should justify its existence. Every state variable should represent meaningful state. Every effect should have a reason. Every event listener should have a lifecycle. Every CSS rule should have a purpose.

Do not generate unnecessary abstractions, wrapper components, helper functions, configuration layers, hooks, utility files, types, interfaces, services, providers, contexts, or dependencies when a simpler implementation is sufficient. Do not create multiple components that perform essentially the same job. Do not create abstractions for hypothetical future requirements. Do not build an entire design system, state-management system, utility library, or component framework when the project does not need one.

Do not duplicate CSS with slightly different class names. Do not hardcode values that should be shared design tokens. Do not introduce arbitrary magic numbers throughout the codebase. Reuse existing components, variables, utilities, functions, styles, and architectural patterns before creating new ones.

Follow the project's existing naming conventions, file structure, state-management patterns, component conventions, accessibility practices, error-handling patterns, and coding style. Do not impose a generic architecture simply because it is familiar. Existing architecture is context, not something to “clean up” automatically.

Do not install a library to solve a problem that can reasonably be solved with existing project functionality or a small amount of native code. Dependencies have a maintenance cost. Do not add packages for trivial animations, icons, date formatting, class merging, state management, utilities, or other functionality that does not genuinely warrant a dependency.

Avoid enormous components containing unrelated functionality, but also avoid splitting trivial markup into dozens of meaningless micro-components. Component boundaries should represent meaningful units of behavior, reuse, ownership, or complexity.

### INSPECT BEFORE IMPLEMENTING

Before changing code, **inspect the existing implementation**. Do not guess how the project works.

Read the relevant files. Trace the existing data flow. Search for existing implementations of the required behavior. Identify which component, function, style, or utility actually owns the behavior before modifying it.

Do not create a second implementation because the first one was not immediately obvious.

Do not assume a class, function, variable, API, component, hook, route, or file exists. Verify it.

Do not assume how state is stored, how events propagate, how navigation works, how styles are applied, or how data is persisted. Inspect it.

Before adding something new, ask:

1. Does this already exist?
2. Can the existing implementation be extended?
3. Can an existing component or utility be reused?
4. Is this abstraction genuinely necessary?
5. What existing behavior could this change break?

The implementation should be based on the **actual codebase**, not an imagined version of it.

### MAKE THE SMALLEST COHERENT CHANGE

Prefer the smallest change that completely solves the problem.

Do not rewrite entire files when changing one component. Do not replace working architecture merely because a different implementation is easier to generate. Do not refactor unrelated code while implementing a feature. Do not rename existing APIs, classes, variables, files, or components without a concrete reason.

Avoid “while I'm here” refactors.

If an existing function already solves most of the problem, extend it instead of creating a competing implementation beside it.

A change should have a clear boundary: **what changed, why it changed, and what intentionally did not change.**

### NEVER PAPER OVER PROBLEMS

Never hide bugs with additional code.

Do not use arbitrary delays, repeated retries, excessive `setTimeout`, forced re-renders, unnecessary `!important`, giant CSS overrides, duplicated event handlers, polling when an event-driven solution exists, fake loading states, hardcoded coordinates, or repeated initialization to make a bug appear fixed.

Do not silence errors with empty `catch` blocks.

Do not add `try/catch` merely to prevent an error from appearing. Handle the actual failure mode or allow the error to surface appropriately.

Do not use defensive programming for impossible states simply to make code look “robust.”

Do not add fallback behavior that silently changes the product's behavior.

Do not mask race conditions with arbitrary delays.

Do not solve a rendering problem by continuously forcing rendering.

Do not solve a state problem by duplicating state.

Do not solve a CSS problem by adding increasingly specific selectors.

Find the underlying cause and fix it at the correct layer.

### DO NOT DESTROY WORKING CODE

Existing code is not guilty until proven guilty.

Do not rewrite functioning code simply because it is not how you would personally implement it. Preserve behavior unless there is a concrete reason to change it.

Do not replace stable implementations with fashionable patterns simply because they are newer.

Do not migrate frameworks, libraries, APIs, state management, CSS architecture, or build tooling unless explicitly required.

Do not “modernize” unrelated code during a feature change.

Do not remove apparently unused code without verifying whether it is referenced dynamically, externally, or through configuration.

Do not change public behavior while claiming to perform a visual or internal refactor.

### NO GENERATED BOILERPLATE

Do not leave behind dead code, unused imports, unused variables, commented-out implementations, placeholder functions, unnecessary TODOs, console logging, debug statements, duplicate event listeners, redundant state, unnecessary effects, generated boilerplate, empty wrapper elements, unused CSS classes, unreachable branches, or abandoned experiments.

Do not add comments that merely translate obvious code into English.

Comments should explain **why**, not narrate **what** the code already clearly says.

Avoid generic comments such as:

- “This function handles...”
- “Set the state...”
- “Loop through the items...”
- “Initialize the component...”

Only comment when the reasoning would otherwise be difficult to understand.

### STATE AND DATA HYGIENE

Do not maintain multiple sources of truth for the same piece of state.

If a value can be derived from existing state, derive it instead of storing a second copy.

Do not synchronize two pieces of state with effects when one can be derived from the other.

Do not use state for values that do not affect rendering.

Do not trigger effects merely because an effect is available.

Do not add effects to perform work that belongs directly inside an event handler or ordinary calculation.

Do not mutate state or shared objects in ways that conflict with the project's existing architecture.

Do not introduce global state unless the state genuinely needs to be global.

Keep data ownership obvious. A future developer should be able to determine where a value comes from without tracing a maze of providers, hooks, callbacks, and intermediate objects.

### DOM AND EVENT HYGIENE

Do not repeatedly query, recreate, or manipulate the DOM when the framework already provides an appropriate mechanism.

Do not attach listeners repeatedly during renders or lifecycle events.

Every manually registered listener, observer, timer, subscription, animation frame, or external resource must have an appropriate cleanup path.

Do not create observers or timers inside effects without considering their lifecycle.

Do not trigger expensive work on every mouse movement, scroll event, resize event, or keystroke without an intentional performance strategy.

Use event delegation where appropriate rather than attaching hundreds of identical listeners.

Do not create duplicate DOM structures simply to achieve a visual effect that CSS can handle.

### CSS DISCIPLINE

Do not solve every styling problem by adding another override.

Avoid selector specificity wars.

Avoid excessive `!important`.

Do not duplicate values that already exist as design tokens.

Do not introduce near-identical spacing, radius, shadow, color, or typography values without a deliberate reason.

Do not create dozens of one-off utility classes when the project already has a coherent styling system.

Do not use inline styles for values that should belong in the stylesheet or design-token system.

Do not introduce arbitrary breakpoints. Reuse the project's existing responsive strategy unless a new breakpoint is genuinely required.

Do not use CSS animations simply because the page feels empty.

### PERFORMANCE IS PART OF CORRECTNESS

Do not sacrifice performance for visual novelty.

Avoid unnecessary re-renders, expensive layout calculations, forced synchronous layout, excessive DOM nodes, oversized assets, unnecessary JavaScript-driven animations, high-frequency state updates, and effects that run continuously without need.

Do not animate properties that cause avoidable layout or paint work when a compositor-friendly alternative is appropriate.

Do not attach expensive calculations directly to high-frequency events without throttling, debouncing, batching, or another appropriate strategy.

Do not add blur, backdrop filters, shadows, particle systems, canvases, gradients, or animated effects indiscriminately. Visual effects have a performance cost.

Do not optimize prematurely, but do not knowingly introduce expensive behavior for decoration.

If the existing project contains performance mechanisms, preserve them.

### RESPONSIVE BEHAVIOR

Do not treat mobile as a scaled-down desktop.

Do not randomly hide elements simply because the viewport is smaller.

Do not introduce dozens of device-specific overrides.

Responsive behavior should follow the existing layout system and preserve hierarchy, usability, and interaction.

Do not hardcode dimensions that cause overflow or clipping at common viewport sizes.

Test the mental model at narrow mobile, standard desktop, and large desktop widths before considering the implementation complete.

### ACCESSIBILITY IS NOT OPTIONAL POLISH

Do not sacrifice semantic HTML for visual appearance.

Use appropriate buttons, links, headings, labels, form controls, landmarks, and interactive elements.

Do not make clickable `<div>` elements when a button or link is appropriate.

Do not remove focus indicators without providing an accessible replacement.

Do not rely exclusively on color to communicate state.

Do not use placeholder text as a substitute for labels.

Interactive elements should have meaningful accessible names.

Respect keyboard navigation.

Respect reduced-motion preferences where appropriate.

Accessibility should be built into the implementation rather than added as a final checklist.

### ERROR HANDLING AND EDGE CASES

Handle real failure modes, not imaginary ones.

Do not silently swallow errors.

Do not invent elaborate recovery systems for situations the application cannot realistically encounter.

Do not display fake success states.

Do not leave users with broken controls when an operation fails.

Consider realistic edge cases such as empty data, missing data, slow operations, failed operations, unusually long text, large collections, repeated interaction, rapid interaction, and interrupted operations when they are relevant to the feature.

Edge-case handling should remain proportional to the feature's complexity.

### DEPENDENCY DISCIPLINE

Every new dependency must have a concrete reason.

Do not add packages because they are popular, convenient, or commonly used by AI-generated projects.

Before adding a dependency, determine whether:

- the project already provides the capability,
- the platform provides the capability,
- a small native implementation is sufficient,
- an existing dependency already solves the problem.

Do not introduce multiple libraries that overlap in functionality.

Do not create dependency sprawl for minor conveniences.

### NO FAKE COMPLETENESS

Never pretend a feature is complete when only the interface exists.

Do not create buttons that appear functional but do nothing.

Do not create fake loading indicators instead of implementing the operation.

Do not use mock data in production UI unless explicitly requested.

Do not simulate API responses, persistence, authentication, search, filtering, sorting, uploads, downloads, or other functionality merely to make a demo look finished.

If something genuinely cannot be implemented, preserve the correct interface and make the limitation explicit rather than fabricating functionality.

### PRESERVE PRODUCT LANGUAGE

Do not invent terminology.

Reuse the project's existing vocabulary, labels, naming conventions, and information architecture.

Do not rename concepts merely to make copy sound more “premium,” “modern,” or AI-generated.

Do not replace clear language with vague marketing language.

Do not use meaningless phrases such as “seamless experience,” “next-generation platform,” “powerful solution,” or “revolutionary workflow” unless the product actually uses that language intentionally.

### NO AI-STYLE COMMENTARY OR SELF-CONGRATULATION

Do not add comments, documentation, copy, or UI text that announces how clean, elegant, scalable, modern, powerful, optimized, or production-ready the implementation is.

The implementation should demonstrate those qualities instead of claiming them.

Do not write comments explaining that something is “best practice” unless that explanation is actually necessary.

Do not add excessive documentation for straightforward code.

### VERIFY BEFORE FINISHING

Before finalizing an implementation, perform a deliberate review.

Check for:

- duplicated logic
- duplicated CSS
- unnecessary abstractions
- unnecessary dependencies
- unused imports
- unused variables
- dead code
- unnecessary state
- unnecessary effects
- redundant event listeners
- missing cleanup
- magic numbers
- arbitrary delays
- excessive `!important`
- giant components
- meaningless micro-components
- generic variable names
- invented product language
- fake functionality
- accessibility regressions
- responsive regressions
- performance regressions
- accidental behavior changes
- unnecessary file changes
- unrelated refactors

Then ask:

**Does this code actually belong in this codebase?**

**Could an experienced developer understand why every significant piece exists?**

**Did I reuse something that already existed instead of generating another version?**

**Did I change anything that did not need to change?**

**Would this implementation still make sense if nobody knew an AI was involved?**

If the answer to any of these is no, revise the implementation.

### FINAL STANDARD

The final result must not feel like an AI-generated website or an AI-generated codebase.

It should feel like an experienced developer examined an existing product, understood its architecture and visual language, made a deliberate change, and stopped when the problem was actually solved.

**Do not maximize output. Maximize intent.**

**Do not maximize abstraction. Maximize clarity.**

**Do not maximize visual effects. Maximize hierarchy.**

**Do not maximize code. Maximize correctness.**

The objective is not to make the work look less modern. The objective is to make it look **specific, deliberate, technically grounded, and genuinely authored.**
