# script.md · ep11 (2-minute narration, 13 beats)

You ask AI the same question three times, and it can give you three answers — the punctuation differs, and by the third run even the conclusion has changed.

---

This isn't a bug. It isn't "thinking"; it's rolling a die — once for every word it says. This operation is called sampling: draw one from a table and append it. So when you use AI to write copy, edit code, or fill in forms, whether the result is stable all depends on how that die turns.

---

Each time it computes only one thing: how likely each next word is. You say "The weather today is really," and it computes a table — "good" 60%, "not bad" just under 20%, "hot" 10%, and everything else combined only 10%.

---

Pick one, append it, reread the whole sentence, compute the next word. So if the first die leans a little, the path drifts further and further — one step off, every step off.

---

If you want it to behave, there are knobs to turn. The first is called temperature; it controls how sharp this table is — literally: low temperature, sharp table.

---

At low temperature, "good" is 95%, almost no suspense; at high temperature the table is flattened, "hot" also gets a 10% chance, and the language starts to run wild. The same compliment: this time it says "really nice," next time it gives you "hot enough to fry an egg."

---

The second knob is more direct: keep only the small set whose cumulative probability reaches 90%, and cut off the entire long tail behind it so it can't improvise. It's called top-p, and that p is the probability line.

---

Sounds like if you turn temperature to zero and always pick the highest-scoring word, the output should be identical every time.

---

It isn't. The server batches your request together with other people's requests. With one more person in the batch, the order of addition changes.

---

The last digit differs by a little, and the word that should have been "good" slips to "not bad." From that one word on, everything after it drifts, and you end up on two completely different paths.

---

Someone took the same question, temperature zero, and ran it 1000 times, getting 80 different answers. The first 102 words were identical; divergence began at word 103.

---

So stability isn't something you tune; it's something you verify. Editing code, running tests, filling in forms: push temperature to 0–0.2, then add a validation step — let it write, let the program judge correctness, rerun on failure, and don't expect one-shot correctness.

---

Brainstorming titles, naming things: the opposite — set temperature to 0.8 or above, ask for ten at once, and you pick. Don't turn temperature and top-p together. Back to those three answers at the start — it makes a legal choice at every step; the choice has to stay in your hands.
