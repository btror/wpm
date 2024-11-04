# wpm plugin
This oh-my-zsh plugin allows users to test and improve their typing speed directly in the terminal. It provides customizable word lists, tracks results for each test session, and displays detailed metrics like words per minute (WPM), keystrokes, accuracy, and correct/incorrect counts. Results are stored in JSON format for easy tracking and analysis.


## Setup

### oh-my-zsh
Place the `wpm` folder in `.oh-my-zsh/custom/plugins`.

Add `wpm` to the `plugins` array in your `.zshrc` file:
```
plugins=(... wpm)
```

Make sure `ZSH_CUSTOM` is set:
```
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
```

### Required Packages
```
sudo apt install jq
```

## Usage

### Functions
Start a speed test via:
```
wpm_test <seconds>
```

### Example
Select a word list txt file in the `lists` folder to use.
```
(10:03pm)──> wpm_test 60
╔═════════════════════════════════════════════╗
║                 Word Lists                  ║
╠═════════════════════════════════════════════╣
║  1.         words_top-1000-english-adv.txt  ║
║  2.          words_top-250-english-adv.txt  ║
║  3.         words_top-250-english-easy.txt  ║
╚═════════════════════════════════════════════╝
Select (1-3):
```

Random words are pulled from the list until the timer stops. Correctly typed words are turn green and incorrect ones turn red.
```
────────────────────────────────────────────────────────────────────────────────────────────────────
                       height easy branch short day about piece own bus side                        
                         you young large easy about dog home ball rich blue                         
────────────────────────────────────────────────────────────────────────────────────────────────────
> heigh
```

Results are displayed in a table when the timer runs out.
```
╔══════════════════════════════════════════╗
║                  Result                  ║
╠══════════════════════════════════════════╣
║                                          ║
║                  77 WPM                  ║
║                                          ║
║──────────────────────────────────────────║
║  Keystrokes                         406  ║
║  Accuracy                           96%  ║
║  Correct                             77  ║
║  Incorrect                            3  ║
║──────────────────────────────────────────║
║      words_top-250-english-easy.txt      ║
╚══════════════════════════════════════════╝
```

Every result is stored as an entry in `wpm/stats/stats.json`. Results are stored relative to the txt file name ran against.
```
{
  "words_top-250-english-easy.txt": [
    {
      "date": "11/03/2024 10:10PM",
      "wpm": 77,
      "test duration": 60,
      "keystrokes": 406,
      "accuracy": 96,
      "correct": 77,
      "incorrect": 3
    },
    {
      "date": "11/03/2024 10:07PM",
      "wpm": 4,
      "test duration": 60,
      "keystrokes": 29,
      "accuracy": 100,
      "correct": 4,
      "incorrect": 0
    },
    {
      "date": "11/03/2024 10:02PM",
      "wpm": 78,
      "test duration": 10,
      "keystrokes": 67,
      "accuracy": 100,
      "correct": 13,
      "incorrect": 0
    }
  ],
  "words_top-250-english-adv.txt": [
    {
      "date": "11/03/2024 10:15PM",
      "wpm": 30,
      "test duration": 60,
      "keystrokes": 275,
      "accuracy": 83,
      "correct": 30,
      "incorrect": 6
    }
  ]
}
```

## Configuration
Add as many txt word lists you want in `wpm/lists/`. Words must be on their own line.