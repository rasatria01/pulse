# Quick input cheat sheet

Everything the capture field understands, checked against the parser. Examples
assume it is **Wednesday 25 Nov 2026, 10:00**, with wallets Cash (default), BCA
and GoPay. A new install has only Cash; add the others in Finance. Letter case
does not matter. Enter saves.

## Common combos

| Type this | You get |
|---|---|
| `-35k lunch @gopay #food` | Expense Rp 35.000, GoPay, Food, "lunch" |
| `-25rb parkir kemarin` | Expense yesterday, from the default wallet |
| `+7.5jt salary @bca #income` | Income Rp 7.500.000 to BCA |
| `500k @bca>@gopay topup` | Transfer BCA → GoPay |
| `Standup 09:00` | Task tomorrow 09:00 (09:00 today has passed) |
| `Submit report jumat 15:00 !h #work` | Task Fri 15:00, high priority |
| `Pay internet 350k besok 09:00 #bill` | Bill of Rp 350.000, tomorrow 09:00 |
| `Pay rent 2jt @bca #bills 12/12` | Bill from BCA, category Bills, due 12 Dec |
| `note: weekend meal prep #personal` | Note |

## What it becomes

| Input | Result |
|---|---|
| `note: idea` or `/ idea` | Note (prefix at the start) |
| `-35k lunch` | Expense (`-` stuck to an amount, first word) |
| `+35k refund` | Income |
| `500k @bca>@gopay` | Transfer (two wallets and an amount, no sign) |
| `buy milk` | Task |
| `- buy milk`, `* buy milk` | Task "buy milk" |
| `lunch -35k` | Task "lunch -35k": the sign must come first |
| `@bca>@gopay` | Task: a transfer needs an amount |
| `-50k @bca>@gopay` | Expense, Save blocked until you pick one wallet |

The Kind chip switches between transaction, task and note if the guess is wrong.

## Amounts

| Input | Result |
|---|---|
| `35k`, `25rb`, `25ribu` | 35.000, 25.000, 25.000 |
| `7.5jt`, `7,5jt`, `2juta`, `2m` | 7.500.000, 7.500.000, 2.000.000, 2.000.000 |
| `35,5k` | 35.500 |
| `1.250.000`, `1,250,000` | 1.250.000 |
| `Rp35.000`, `rp.500` | 35.000, 500 |
| `-35.5 coffee` | Invalid, Save blocked (no decimals without a suffix) |
| `1.2345k`, `0`, `35.000,00` | Invalid (not a whole rupiah above 0) |
| `Rp 35.000` | Do not put a space after Rp: "Rp" stays in the text |

On a transaction only the amount with the sign counts. On a task, a number is
money only with `k/rb/jt/m`, `Rp`, thousands separators, or 5+ digits.

| Task input | Result |
|---|---|
| `Plan 2026 trip` | No amount |
| `Pay 50000` | Bill of 50.000 |
| `Walk 2m` | **Careful:** `m` means million, so a Rp 2.000.000 bill |
| `Call 081234567890` | **Careful:** read as an amount. Type `\081234567890` |

## Wallets

| Input | Result |
|---|---|
| `@gopay` | By handle |
| `@gp` | By alias (the wallet's "Other handles") |
| `@go` | By the start of a handle, if only one wallet matches |
| `@ovo` (none) | Save blocked: unknown wallet |
| no `@` on a transaction | Default wallet, with a warning chip |
| `@bca>@gopay`, `@bca > @gopay` | Transfer from → to (must differ) |
| `Pay rent 2jt @bca` | The bill will be paid from BCA |

An archived wallet blocks Save. Only the first `@wallet` counts.

## Categories and tags (`#`)

Categories available today: `#food`, `#transport`, `#bills` (expense) and
`#income` (income).

| Input | Result |
|---|---|
| `-5k #food` | Category Food |
| `-5k #dev #food #transport` | Food; `dev` and `transport` become tags |
| `-5k parkir` | Uncategorized (a chip asks) |
| `Cook #food` | Task with the tag `food` (not a bill) |
| `Pay 50k #bills` | Bill with category Bills |
| `500k @bca>@gopay #food` | Transfers have no category: tag |

Tags use letters a–z, digits, `_` and `-`. Anything else stays as text.

## Bills

A task is a bill if it has an amount **or** `#bill`.

| Input | Result |
|---|---|
| `Pay water #bill` | Bill with no amount yet |
| `Internet 350k` | Bill of 350.000 |
| `Pay rent 2jt @bca #bills` | Bill with wallet and category preset |

`#bill` marks a bill; `#bills` is the category. When you complete a bill, a
sheet records the expense (default wallet and Bills if you gave none). Close
the sheet and it waits under "Needs confirmation".

## Priority (tasks only)

| Low | Medium | High |
|---|---|---|
| `!low` `!l` `!rendah` | `!med` `!m` `!sedang` | `!high` `!h` `!tinggi` |

The last one wins. On a transaction it stays in the description.

## Times

| Input | Result |
|---|---|
| `09:00`, `9.30` | 09:00, 09:30 |
| `9am`, `9pm` | 09:00, 21:00 |
| `jam 9`, `pukul 14.00` | 09:00, 14:00 |
| `Call 9` | Not a time (needs `jam`, `:` or am/pm) |
| `jam 2 siang` | 14:00 (siang: 1–4 become 13–16) |
| `jam 5 sore` | 17:00 (sore: 3–6 become 15–18) |
| `jam 7 malam` | 19:00 (malam: 6–11 become 18–23) |
| `jam 7 pagi` | 07:00 |
| `pagi`, `siang`, `sore`, `malam`, `nanti malam` | 08:00, 12:00, 16:00, 19:00, 19:00 |
| `14:00-15:30`, `9am-1pm`, `jam 9-10` | Start and end |
| `23:00-01:00` | Ends the next day |

**Careful:**

- A day word alone is a time. `-35k makan siang` becomes "makan" at 12:00.
  Type `makan \siang` to keep the word.
- The day word goes after the hour: `jam 8 nanti malam` is 20:00, but
  `nanti malam jam 8` is 08:00.
- Without `jam`, `7 malam` leaves "7" in the text.

## Dates

| Input | Result |
|---|---|
| `today`, `tdy`, `hari ini`, `hr ini` | 25 Nov |
| `besok`, `bsk`, `tomorrow`, `tmr` | 26 Nov |
| `lusa` | 27 Nov |
| `kemarin`, `kmrn`, `yesterday` | 24 Nov |
| `senin` … `sabtu`, `mon` … `sun`, `jumat`, `jum'at` | Next such day after today |
| `minggu`, `ahad`, `hari minggu` | Sunday 29 Nov |
| `minggu depan`, `next week` | Monday 30 Nov |
| `in 3 days`, `3 hari lagi` | 28 Nov |
| `12/12`, `12 des`, `12 dec` | 12 Dec (day first) |
| `12/12/2027`, `1 jan 2027` | That date |
| `31/2`, `tanggal 1` | Not a date; stays as text |

Only the first date and first time are read.

**Careful:**

- A date without a year that has passed means **next year**: `-5k 24/11` is
  24 Nov **2027**. Backdate with `kemarin` or add the year.
- On a transaction, `senin` is a future date (warning chip).
- English words count: `Buy sun screen` is due Sunday. Type `\sun`.
- Punctuation breaks a word: `besok,` is not read.

## How dates apply

| Kind | Date only | Time (with or without date) | Nothing |
|---|---|---|---|
| Task | Due date | Scheduled; a passed time with no date moves to tomorrow | Inbox |
| Expense, income, transfer | That day at 12:00 | That date and time, never moved | Now |
| Note | Ignored | Ignored | |

## Escape with `\`

| Input | Result |
|---|---|
| `Fix \#123 crash` | Text "#123", not a tag |
| `Read \besok` | The word "besok", no date |
| `\50000` | A number, not money |

`\` in front of a word makes the whole word plain text.

## Notes and checklists

In the capture field, `note:` or `/` makes a one-line note. Only `#tags` are
read; dates, amounts and `@` stay as text. Write longer notes in Notes.

Inside a note, a checklist line becomes a task:

| Line in a note | Result |
|---|---|
| `- [ ] Call mum besok` | Task "Call mum", due tomorrow |
| `- [ ] Pay water 150k @bca 12/12` | Bill of 150.000 from BCA, due 12 Dec |
| `* [ ] Report !h jam 9` | High priority task at 09:00 |
| `- [x] Done thing` | Task already done |

- Read words are removed from the line, and a hidden-in-preview `^t…` id is
  added. Leave the id; delete the whole line to delete the task.
- Ticking a line completes the task. A ticked bill waits for confirmation.
- Editing an existing line reads only newly typed date, time and priority words.
- Lines inside ``` code blocks are ignored.

## Chips and undo

Chips show what was read (Kind, Amount, Wallet, Category, Date, Priority,
Tags). Tap one to change it; your pick wins over the text. Red chips block
Save. After saving you have 5 seconds to Undo.

## Recurring

There is no shorthand. Set up recurring items in Finance → Recurring.

## Promised but not built

- **Managing categories:** there is no screen to add or rename categories or
  give them aliases, so only the four above can be typed.
- **Date chip without a time:** the picker always sets a time. To set a due
  date only, type it (`besok`, `12/12`).
- **Speed targets:** under 3 s to save and under 2 ms to parse are not yet
  measured on a phone (parsing is well under 2 ms on the PC).
