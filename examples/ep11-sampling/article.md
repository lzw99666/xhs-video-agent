# article.md · ep11
## Why does AI answer the same question differently every time?

### The symptom: three answers

Ask AI the same question three times and you get three answers: the punctuation differs, and by the third run even the conclusion has changed.

Most people's first reaction is "the model is broken." It isn't. It isn't getting smarter or dumber — every time it produces a word, it rolls a die.

### The mechanism: one word at a time

A model doesn't write a whole paragraph in its head and then spit it out. It computes one thing at a time: **how likely each next word is**.

Give it "The weather today is really" and it scores every word in a vocabulary of tens of thousands, then normalizes those scores into probabilities. In plain terms, that's a table: "good" 60%, "not bad" just under 20%, "hot" 10%, and all the remaining words combined only 10%.

Then it picks one and appends it; then it rereads the whole sentence and computes the next word. So if the first fork leans a little, everything after it drifts further — one step off, every step off. This "draw once per word" operation has a formal name: **sampling**.

### Two knobs

Since it draws from a table, there are knobs you can turn.

**The first is temperature.** It doesn't control "how smart" the model is; it controls how peaked the table is. Low temperature makes the table sharp: the highest-scoring word is pushed to 95%, with almost no suspense. High temperature flattens the table: a fringe option like "hot" also gets a 10% chance, and the language starts to run wild — the same compliment comes out as "really nice" this time and "hot enough to fry an egg" the next. So the same model can write official documents or comedy bits; the difference is only in temperature.

**The second is top-p.** It's more direct: sort all candidates by probability from high to low, keep only the small set whose cumulative probability reaches 90%, and cut off the entire long tail behind it so it can't improvise. This method is called nucleus sampling, proposed in a 2019 paper on "neural text degeneration"; the motivation was to cut off the unreliable long tail.

### The twist: turn it to zero and it's still unstable

At this point it's tempting to conclude: then I'll turn temperature to zero, always pick the highest-scoring word, and the output should be identical every time.

It isn't.

On your own computer, sure, it is. But a production server doesn't work that way — it batches your request together with other people's requests and computes them as one batch. With one more or one fewer person in that batch, the order in which floating-point additions are split and reordered changes, and the last decimal ends up slightly different.

What does that tiny difference do? A word that should have been "good" slips to "not bad." From that one word on, every word after it drifts too, and you end up on two completely different paths.

Someone ran an experiment: same question, temperature zero, 1,000 runs. Out of 1,000 runs, they got 80 different answers. The first 102 words were exactly identical; divergence began at word 103.

The vendor documentation agrees: above zero, output is random and different results are expected; for consistent, repeatable output, use temperature zero. But it also admits that results can still differ at temperature zero. That means "temperature zero" is "as reproducible as possible," not "guaranteed identical."

### So what should I do?

**When you need stability** — editing code, running tests, filling in forms, extracting information: push temperature to 0–0.2, then **add a validation step**. Let it write, let the program judge correctness, rerun on failure. Don't expect one-shot correctness: low temperature only means "prefers the most likely word"; confidently wrong is still wrong.

**When you need divergence** — brainstorming titles, naming things, ideation: the opposite — set temperature to 0.8 or above, ask for ten candidates at once, and pick yourself.

One more rule: don't turn temperature and top-p at the same time. If you move both, you can't tell which one is to blame. Change one first.

### The landing point

Back to those three answers at the start — it wasn't confused; it was making a legal choice at every step.

The temperature is its; the choice has to stay in your hands.
