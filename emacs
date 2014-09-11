(when (>= emacs-major-version 24)
  (require 'package)
  (package-initialize)
  (add-to-list 'package-archives '("melpa" . "http://melpa.milkbox.net/packages/") t)
  )

(global-linum-mode 1)
(global-font-lock-mode 1)
(show-paren-mode 1)
(setq show-paren-style 'expression)

(column-number-mode 1)
(line-number-mode 1)

(package-initialize)
(evil-mode 1)

(add-hook 'python-mode-hook 'jedi:setup)
(setq jedi:complete-on-dot t)

