# React

## Rule: Don't reach for `useMemo`/`useCallback` by default

**Do:** Use `useMemo`/`useCallback` only when you have a measured perf reason (a heavy compute, a large list re-render) or when you need a stable reference for a downstream contract (a `useEffect` dependency you control, a `React.memo`'d child's prop, a context value). When you do use them, leave a one-line comment explaining the reason.
**Don't:** Wrap every derived value in `useMemo` and every handler in `useCallback` "to be safe" or because the AI suggested it. The hooks add code, dependency arrays you have to keep correct, and noise that hides which values are actually expensive.
**Why:** Most `useMemo`/`useCallback` calls in feature code don't help — the memo overhead and dep-array maintenance cost more than the recomputation they save. Defaulting to memoization makes components harder to read and harder to refactor. Reviewers reliably read large numbers of memos as a code smell.
**Example:** `const adminColumns = useMemo(() => getAdminColumns(planTypes, statuses), [planTypes, statuses]);` is justifiable _only if_ `adminColumns` is a dep of something memoized downstream (e.g. a `useCallback`). If it's just consumed inline in JSX, drop the `useMemo`.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2878984229
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/13#discussion_r2801465296
**Detection:** A component file with 3+ `useMemo`/`useCallback` calls, none of which have a comment justifying the memoization, and where the memoized values are not themselves consumed by other hooks' dep arrays or `React.memo`'d children.

## Rule: Don't extract custom hooks for trivial state

**Do:** Keep simple `useState` + a setter wrapper inline in the component. Extract a custom hook only when (a) the same logic is reused across 2+ components, (b) the logic spans multiple `useEffect`/`useMemo`/`useState` calls that need to evolve together, or (c) the hook encapsulates an external resource lifecycle (subscription, websocket, polling).
**Don't:** Wrap a single `useState<GridFilterModel>(INITIAL_FILTER_MODEL)` plus a setter in a `useServerFilter` hook used in one place. Inline it in the consuming component.
**Why:** Premature hook extraction adds an indirection layer for no abstraction win. The component reading the state now has to jump to a separate file to understand what's going on, and the hook ends up with one consumer (so it can't actually be reused or evolved meaningfully).
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2874821532
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2874849572
**Detection:** A new `src/hooks/use<Name>.ts` (or `.tsx`) file with one consumer in the same PR, especially when it wraps a single `useState`/`useReducer` call without additional effects or coordination.

## Rule: Files that import React or use JSX must be `.tsx`

**Do:** Name a file `.tsx` if it imports `React`, uses JSX syntax, or returns React elements. Use `.ts` for pure TypeScript modules with no React or JSX dependency.
**Don't:** Import React (or JSX-using libraries) from a `.ts` file. The TypeScript compiler treats `.ts` and `.tsx` differently for JSX parsing, and many bundlers will fail or silently ignore JSX in `.ts`.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2874821532
**Detection:** A `.ts` file that contains `import React` (or any `import … from 'react'` / `import … from '@mui/...'` that brings in JSX-returning components).

## Rule: Don't use `React.FC` namespace types without importing React

**Do:** Import the type you actually need from `react`: `import { FC, ReactNode } from 'react';` and annotate as `const Foo: FC = …` or `const Foo: FC<Props> = …`. Be consistent across the codebase.
**Don't:** Write `const Foo: React.FC = …` in a file that doesn't `import React`. The `React.X` namespace requires `React` to be in scope; `Cannot find namespace 'React'` is the resulting TS error.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2874090159
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2874090230
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2874090342
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/38#discussion_r2795707608
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/38#discussion_r2795707629
**Detection:** A `.tsx` file uses `React.FC` / `React.ReactNode` / `React.X` without a top-level `import React from 'react'` (or `import * as React from 'react'`).

## Rule: Utility/helper files must be pure — no React state setters

**Do:** Keep `src/utils/` (and similar non-component folders) free of React-specific code. Helpers should be pure functions: input → output, no hooks, no `setState` calls. If you need a React handler, define it in the component (or a custom hook in `src/hooks/`).
**Don't:** Put a function in `src/utils/filterUtils.ts` that takes a `setFilterModel` prop and calls it. That function belongs as a handler on the component that owns the state.
**Why:** Mixing presentation/state concerns into utility files makes them un-testable in isolation, makes the data flow harder to trace, and invites circular dependencies. Utilities should be pure so they can be unit-tested without React Testing Library.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2874888286
**Detection:** A function in `src/utils/`/`src/helpers/` that accepts a `set<Name>` callback parameter (React setter pattern) or imports from `react`/`@mui/*`.

## Rule: Use the component library's first-class props before reinventing them

**Do:** Use built-in props for common concerns: `<DataGrid loading={isLoading} … />`, `<Menu onClose={…} />`, `<TextField error helperText={…} />`. Read the library docs before writing a ternary or wrapper component.
**Don't:** Build `{isLoading && !data ? <Spinner /> : <DataGrid … />}` when `<DataGrid loading={isLoading} … />` already handles the same UX correctly. Don't make a `Menu` controlled with `open={Boolean(anchorEl)}` and forget to wire `onClose`.
**Why:** First-class props are tested, accessible, and consistent across the app. Reinvented equivalents diverge over time and lose accessibility behaviors (Esc to close, ARIA states, keyboard nav).
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2874863540
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2874090207
**Detection:** A loading/error/open ternary or conditional render around a component whose props page lists a built-in equivalent (`loading`, `error`, `open`/`onClose`).

## Rule: react-query keys must include every variable that changes the response

**Do:** Include every input to the request in the `queryKey`: `['reimbursements', tab, page, pageSize, filters, sort]`. Update the same keys in `invalidateQueries` calls so cache hits and invalidations stay aligned.
**Don't:** Use a coarse key like `['reimbursements']` (or `[QueryKey.REIMBURSEMENTS, tab]`) when the response varies by `page`/`pageSize`/`filters`. The cache will return stale data for one combination after another combination's response was fetched.
**Why:** react-query keys are the cache identity. A key that doesn't reflect every dimension of the request causes silent cross-contamination — page 2's data shows up on page 1, filtered results show up unfiltered, etc.
**Example fix:** `queryKey: [QueryKey.REIMBURSEMENTS, tab, paginationModel.page, paginationModel.pageSize, JSON.stringify(activeFilters), sortModel]`. Mirror the same shape in `invalidateQueries({ queryKey: [QueryKey.REIMBURSEMENTS] })` (prefix-match invalidation is fine and intentional).
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2879425978
**Detection:** A `useQuery({ queryKey: […] })` whose deps don't include all variables passed into the `queryFn`'s request body.

## Rule: Follow the project's React file/section ordering standard

**Do:** When the team has a documented React standards file (file structure, hook ordering, exports), follow it for every new component. Match an existing exemplar component if the standard lives in code rather than docs.
**Don't:** Invent a new layout for a component file (effects before state, ad-hoc helper sections, inline types in unusual places) when the team's other components follow a fixed pattern.
**Why:** Consistent file layout makes a 300-line component scannable in seconds. Deviating means every reviewer has to re-orient.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2878965492
**Detection:** A new `.tsx` component whose section order (imports → types → constants → component → hooks inside component → handlers → JSX → exports) differs from the team's other recent components or documented standard.

## Rule: Don't invent new test categories — stick to project-standard categories

**Do:** Use the test categories the project already has (typically: unit tests next to the code, e2e/Playwright tests in a dedicated folder). New tests pick one of the existing categories.
**Don't:** Invent a third category like `Admin.interactions.test.tsx` without team agreement and a documented place where it fits in the test pyramid. If you think a new category is needed, raise it as a separate proposal — don't smuggle it in via a feature PR.
**Why:** Each test category implies a runner, a CI step, conventions, and ownership. Inventing one mid-PR fragments the test suite and forces every future PR to make the same choice.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/63#discussion_r2874823821
**Detection:** A new `*.<category>.test.tsx` file where `<category>` doesn't match the project's existing test-file naming convention.

## Rule: Server-side pagination requires `paginationMode="server"` + `rowCount` + backend total

**Do:** When using server-side pagination on a `DataGrid` (or any paginated table component), wire it up end-to-end:

1. **Backend:** return pagination metadata (`meta: { total, page, limit }`) in the API response.
2. **Service:** pass `total` through to the component (don't drop it during transformation).
3. **Component:** set `paginationMode="server"`, `rowCount={meta.total}`, `paginationModel`/`onPaginationModelChange`, and `pageSizeOptions`.
   **Don't:** Pass paginated data into `<DataGrid rows={data} />` without `paginationMode="server"`. The grid will treat the current page's slice as the entire dataset, hide the pagination controls past page 1, show wrong totals, and silently break "next page". Don't omit `rowCount` — the grid can't render correct controls without it.
   **Why:** `DataGrid`'s default is client-side pagination — it assumes `rows` is the full dataset. Forgetting `paginationMode="server"` is the most common server-pagination bug; it shows up as "page 2 is empty" or "the total at the bottom is wrong" and the cause is invisible at the call site.
   **Example:** `<DataGrid rows={data} rowCount={meta.total} paginationMode="server" paginationModel={paginationModel} onPaginationModelChange={setPaginationModel} pageSizeOptions={[10, 25, 50]} … />`
   **Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/38\#discussion_r2842032282
   **Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/38\#discussion_r2842032335
   **Detection:** A `<DataGrid>` (or equivalent paginated table) whose data source is a paged API call but missing any of `paginationMode="server"`, `rowCount`, or whose API response has no `meta.total`.

## Rule: Don't manually `refetch` in `useEffect` when `queryKey` already covers the dependency

**Do:** Put every variable that changes the response into the `queryKey`. React Query will refetch automatically when any element of the key changes. Let the library do the work.
**Don't:** Add a `useEffect(() => { refetch(); }, [tab])` "to make sure the query updates when the tab changes" while `tab` is already part of the `queryKey`. This fires a duplicate request — the key change already triggered one.
**Why:** Manual `refetch()` calls compete with the library's own invalidation logic, double-fire requests, and create race conditions where the second response can overwrite the first. The `queryKey` is the contract; trust it.
**Example fix:** Delete the `useEffect`. If `queryKey` is missing a variable, add it to the key — don't paper over the bug with a manual refetch.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18\#discussion_r2807081279
**Detection:** A `useEffect` whose body is (effectively) `refetch()` (or `queryClient.invalidateQueries`) and whose dependency array is a subset of the variables already present in the corresponding `queryKey`.

## Rule: When two complementary APIs are needed (e.g., `valueGetter` + `valueFormatter`), comment why both

**Do:** When using two API hooks together that look redundant — `valueGetter` parses raw → typed, `valueFormatter` types → display string; or `select` + `transform`; or `parse` + `serialize` — add a one-line comment at the column/field describing the role split: `// valueGetter parses ISO string → Date for sort/filter; valueFormatter renders the locale string.`
**Don't:** Leave both in place with no comment and assume reviewers will figure out the contract. They will ask "do we need both?" and you will paste the same explanation in every PR.
**Why:** MUI DataGrid, react-table, formik, and many other libraries have these dual-API patterns where one feels redundant unless you know the internals. A comment turns one author's tribal knowledge into something the next reader can verify in five seconds. Reviewer questions are the signal — answer the question in the code, not the PR thread.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18\#discussion_r2817914306
**Detection:** Both `valueGetter` and `valueFormatter` (or analogous `parse`/`format`, `select`/`transform` pairs) on the same field/column with no inline comment explaining why both are needed.

## Rule: Use the project's design-system components instead of bare HTML or hardcoded UX strings

**Do:** Render loading/error/empty states with the project's existing components (`<Loading />`, `<Alert severity="error">`, `<EmptyState />`). Search the components folder before introducing inline `<div>Loading...</div>` or `<div>{error.message}</div>`.
**Don't:** Hard-code `<div>Loading...</div>`, `<p style={{ color: 'red' }}>{error}</p>`, or "If error, hide the entire grid". The project ships standard primitives for these states; using them keeps a11y, theming, and copy consistent across pages.
**Why:** Each feature page that invents its own loading/error UI drifts from the design system. The text gets stale ("Loading…" vs "Loading data…"), the styling diverges, and screen-reader behavior becomes inconsistent. Also: an error in _one_ query should not blank the whole page — show the inline alert and keep the rest of the UI usable.
**Example fix:** Replace `loading ? <div>Loading...</div> : error ? <div>{error}</div> : <DataGrid …/>` with `{loading && <Loading />}{error && <Alert severity="error">{error.message}</Alert>}<DataGrid loading={loading} rows={rows ?? []} …/>` — the grid stays mounted and shows its own empty/error overlay.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2817924609
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2817925243
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2817929566
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/38#discussion_r2795707676
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/38#discussion_r2795707697
**Detection:** Inline `<div>Loading...</div>` / `<p>Error...</p>` literals in feature components when a `Loading` / `Alert` / equivalent component already exists in the components folder. Or: a render path that returns `null` / hides the main data view when an error occurs, instead of rendering the error inline alongside the data view.

## Rule: Component names are nouns, not verbs

**Do:** Name React components after what they are: `ReimbursementPageHeader`, `UserBadge`, `EmployeeAvatar`. The rendering is implied by the fact that it's a component.
**Don't:** Prefix component names with verbs like `Create…`, `Make…`, `Render…`, `Build…`, `Display…`. `CreateCellHeader` reads like a function that creates a header, not the header itself.
**Why:** Components are values (JSX trees), not actions. Verb prefixes lie about the API ("does it `create` something? mutate? return JSX?") and they're redundant — every component "creates/renders" what it returns. Reserve verb prefixes for hooks (`useFoo`), helpers (`createFoo`, `buildFoo`), and HOCs (`withFoo`).
**Example fix:** `CreateCellHeader` → `CellHeader` (or `ReimbursementPageHeader` if it's specifically the page header for reimbursements). Rename the file, the export, and any imports.
**Source:** https://github.com/cobank-acb/ama-cell-reimbursement-ui/pull/18#discussion_r2818905566
**Detection:** A `.tsx` file whose default/named React component export starts with `Create`, `Make`, `Render`, `Build`, `Display`, `Show` followed by a noun.

## Rule: Don't ship state, handlers, or components wired to nothing reachable

**Do:** Before merging, verify every `useState` setter is called from a reachable UI event, every handler is bound to an element, and every conditionally-rendered component (drawer, modal, dialog) has a reachable trigger that flips its open state. If a CTA was removed in a refactor, remove the dead state with it (or wire a new trigger in the same PR).
**Don't:** Leave `const [isDrawerOpen, setDrawerOpen] = useState(false);` and `<ReimbursementRequestDrawer open={isDrawerOpen} … />` in the file when no `onClick` ever calls `setDrawerOpen(true)`. Don't ship a refactor that swaps the old "Request Reimbursement" button for a "Monthly Submittal" label and forgets to wire the new label's `onClick` to the existing drawer setter.
**Why:** Dead state and unreachable components are an invisible regression — `tsc` is happy (the variables/components are used somewhere), tests still pass (the refactor likely removed the test that opened the drawer), but the user can't perform the workflow at all. The PR description still says "view prior reimbursements" and the QA pass says "renders correctly", and the "Submit a reimbursement" path silently disappears for everyone.
**Example fix:** Either (a) add `onClick={() => setDrawerOpen(true)}` to the new "Monthly Submittal" button, _and_ a test that asserts clicking it opens the drawer, or (b) remove `isDrawerOpen` / `setDrawerOpen` / the `ReimbursementRequestDrawer` element entirely from this PR and ship the drawer trigger in the follow-up PR that introduces a real CTA.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/38#discussion_r2795707644
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/38#discussion_r2795707659
**Detection:** A `useState` setter (`setX`) that has no caller in the file. A conditionally-rendered modal/drawer/dialog whose `open`/`isOpen` prop comes from a state variable that's never set to `true` from any handler. An `onClick={…}` declared on the page that's never assigned to any element.

## Rule: Inline `sx={{ … }}` literals must be extracted to a `style` object

**Do:** Define a single `const style = { mainContainer: { … }, italicText: { … }, planLabel: { … } }` at the bottom of the component file (or in a separate `*.styles.ts` per the project's convention) and reference it from JSX as `<Box sx={style.mainContainer}>`. Apply the same pattern to every `sx` prop in the file in the same PR.
**Don't:** Sprinkle `sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}` across 8 elements in the same JSX tree. Don't extract two of them to a `style` object and leave six inline — pick the convention and apply it uniformly within the file.
**Why:** Inline `sx` objects allocate a new object on every render (defeating MUI's emotion cache memoization), pollute the JSX with style noise that drowns out the structural intent, and prevent reuse — the moment a second element needs the same styling, the inline literal becomes copy-paste with no rename support. The project's documented pattern (see Saki's guide) is a `style` object at the bottom of the component file.
**Example fix:**

```tsx
<Box sx={{ minHeight: '100vh', p: 2 }}>           →   <Box sx={style.mainContainer}>
…
const style = { mainContainer: { minHeight: '100vh', p: 2 }, … } as const;
```

**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/38#discussion_r2795830454
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/38#discussion_r2795831056
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/38#discussion_r2795871052
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2795007997
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2795043619
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2795045974
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2795049242
**Detection:** A `.tsx` file with more than ~2 inline `sx={{ … }}` object literals (especially with multi-property literals containing `display`, `flexDirection`, `alignItems`, etc.). Or: a file that has _both_ a `style` object and inline `sx={{ … }}` literals — pick one.

## Rule: Don't use `href='#'` as a placeholder navigation target

**Do:** Use a real route (`<Link to="/edit-plan">`), an event handler that opens a dialog/drawer (`<Button onClick={() => setEditOpen(true)}>`), or — if the action genuinely doesn't have a target yet — render the element as `disabled` or omit it entirely until the destination exists.
**Don't:** Ship `<a href='#'>Edit Plan</a>` as a "placeholder until we wire it up". Clicking it scrolls the page to the top, changes the URL fragment to `#`, breaks back-button behavior, and gives keyboard/screen-reader users a navigation that goes nowhere.
**Why:** `href='#'` is the JS-era "TODO" that ships to production and lives there. It's worse than no link because it _appears_ clickable, then silently breaks user expectation. Disabled MUI `<Button disabled>Edit Plan</Button>` (or removing the element until the route exists) communicates "not ready yet" honestly.
**Example fix:** `<a href='#'>Edit Plan</a>` → `<Button disabled>Edit Plan</Button>` (until route wired) → `<Link component={RouterLink} to="/plans/edit">Edit Plan</Link>` (when route exists).
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/38#discussion_r2795707676
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/38#discussion_r2795707697
**Detection:** Any `href='#'`, `href="#"`, `href={'#'}`, or `href={\`#\`}`in JSX. Also:`<a onClick={…}>`with no`href` and no role/button semantics.

## Rule: Time-dependent values must be computed inside render, not at module load

**Do:** Read the current date/time _inside_ the component body (`const today = new Date();`) — or, for values that should react to clock ticks, derive them via `useState` + an interval, or via a clock context. The render function reruns; the module body does not.
**Don't:** Compute `const date = new Date().getDate();` at the top of a `.tsx` file and reference it in the JSX. The value is captured once when the bundle loads (or when the route's chunk loads) and is then frozen for the lifetime of the tab — a user who keeps the page open across midnight sees yesterday's date forever.
**Why:** Module-level `new Date()` is a stale-by-default bug that doesn't reproduce in any test (Jest/vitest restart every test) and only surfaces for users who keep tabs open — exactly the population that doesn't report it. The fix is one line; the bug is invisible until production.
**Example fix:**

```tsx
// ❌  computed once at module load
const date = new Date().getDate();
export const ReimbursementNotice = () => <div>Today is the {date}th</div>;

// ✅  computed every render
export const ReimbursementNotice = () => {
  const date = new Date().getDate();
  return <div>Today is the {date}th</div>;
};
```

**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2790772322
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2790772330
**Detection:** A top-level (module-scope) `const X = new Date(...)` / `Date.now()` / `dayjs()` / `new Intl.DateTimeFormat().format(new Date())` in a `.tsx` / `.ts` file whose value is consumed inside a component or hook.

## Rule: Use the data-fetching library's mutation hook for create/update/delete; don't roll your own with `useState`

**Do:** When the project uses `@tanstack/react-query`, write `const mutation = useMutation({ mutationFn, onSuccess, onError });` and call `mutation.mutate(payload)` from the submit handler. Read `mutation.isPending` / `mutation.error` for UI state. Apply the same rule to SWR (`useSWRMutation`), Apollo (`useMutation`), or whatever the project standardizes on.
**Don't:** Roll your own with `const [loading, setLoading] = useState(false); const [error, setError] = useState<Error | null>(null); async function submit() { setLoading(true); try { await api.post(...); } catch (e) { setError(e); } finally { setLoading(false); }}`. You're reimplementing the library's mutation primitive — badly (no retry, no cache invalidation, no `mutateAsync`, no concurrent-mutation guard).
**Why:** A hand-rolled async + `useState` triple (`loading`/`error`/`data`) is the exact case the library exists to solve. Mixing the two patterns within a codebase (queries via `useQuery`, mutations via raw `useState`) makes cache invalidation impossible to reason about — the mutation succeeds but no `useQuery` re-fetches because the manual code never called `queryClient.invalidateQueries`.
**Example fix:**

```tsx
const createReimbursement = useMutation({
  mutationFn: (payload: ReimbursementRequest) =>
    api.createReimbursement(payload),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ["reimbursements", employeeId] });
    onClose();
  },
});
const handleSubmit = () => createReimbursement.mutate(reimbursementRequest);
```

**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2793764720
**Detection:** A submit/save/delete handler in a `.tsx` file that combines `useState` for `loading`/`error` with a raw `await api.*(...)` call, in a project whose `package.json` includes `@tanstack/react-query` (or `swr`, or `@apollo/client`).

## Rule: Don't extract a component unless it's reusable or it tames complexity

**Do:** Inline small JSX fragments in the parent. Extract a sub-component when (a) the same JSX is used in more than one place, _or_ (b) the parent is genuinely too long/complex to read and the sub-component encapsulates a coherent unit (e.g., a 100-line form field group). Name the boundary something concrete the next reader can find ("ReimbursementHeader", not "Section1").
**Don't:** Create `ReimbursementNotice.tsx` (10 lines of JSX, no props, used in one place) just because "components should be small". Don't split a single page into 8 single-use sub-components — the next person trying to update the page's wording has to traverse 8 files to find the string.
**Why:** Premature componentization scatters the page across files and prop boundaries that _don't reflect a real reuse axis_. The reader pays the cost (jump to definition, scroll, return) without getting any reuse benefit. Inlining a 10-line JSX block is fine; you can always extract later when a second use site appears or the parent crosses a complexity threshold.
**Example:** A `ReimbursementNotice` that's 10 lines of `<Box>` + two `<Typography>`s, used only inside `ReimbursementRequestReview`, should be inlined back into the parent. If a `FormDataKeyValVerticalStack` is genuinely reusable across forms, lift it to `src/components/` (not a deeply nested page-specific path).
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2793858806
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/33#discussion_r2793897439
**Detection:** A new component file (single export, < ~30 lines of JSX, no props or one trivial prop, single import site) created in the same PR that introduces its only caller. Especially: a folder of small sibling components where the parent's JSX is now mostly `<Header />`, `<Body />`, `<Footer />`, `<Notice />`.


## Rule: Don't wrap JSX in `<>...</>` when there's already a single parent element

**Do:** Return JSX directly when there's one root element. Use a Fragment (`<>...</>` or `<Fragment>`) only when you actually need to return _multiple_ sibling elements without adding a DOM node. When the immediate parent is already a wrapping component (`<Drawer>`, `<Box>`, `<Stack>`, a layout primitive), put the children directly inside it — no fragment in between.
**Don't:** Wrap a single child in `<>...</>` "just in case". Don't keep a fragment around after refactoring its parent into a real wrapping component (e.g., switching the page from a bare `return <>...</>` to `return <Drawer>...</Drawer>` and leaving `<>...</>` inside the Drawer).
**Why:** A fragment with a single child or inside an already-wrapping parent is dead syntax. It muddies diffs (every reader asks "why a fragment here?"), confuses tools that key off element nesting (testing-library queries, dev tools), and is the most common artifact of an incomplete refactor. Removing it is risk-free and makes intent obvious.
**Example fix:** `<Drawer><><Header /><Body /></></Drawer>` → `<Drawer><Header /><Body /></Drawer>`. `return <>{<MyOnlyChild />}</>` → `return <MyOnlyChild />`.
**Source:** https://github.com/cobank-acb/ama-cell-phone-reimbursement-ui/pull/25\#discussion_r2790093773
**Detection:** A `<>` (or `<Fragment>`) whose immediate parent in the JSX tree is already a wrapping component, _or_ which contains exactly one child element. Especially flag fragments inside MUI layout primitives (`Drawer`, `Box`, `Stack`, `Paper`, `Card`).
