;; vim: et sw=4 ts=4:

;; basic and packages

(require 'cl)
(require 'cask "~/.dotfiles/lib/cask/cask.el")
(cask-initialize)
(require 'pallet)
(pallet-mode t)

;; global editor options

(global-font-lock-mode 1)
;(global-linum-mode 1)
(column-number-mode 1)
(line-number-mode 1)
(show-paren-mode 1)
(setq show-paren-style 'expression)

;; color

(require 'color)
(set-frame-parameter nil 'background-mode 'dark)

;; TODO

;; package: ace-jump

(require 'ace-jump-mode)
(eval-after-load "ace-jump-mode" '(ace-jump-mode-enable-mark-sync))

;; package: ack

(require 'ack)
(defvar ack-history nil
  "History for the `ack' command.")
(defun ack (command-args)
  (interactive
    (let ((ack-command "ack --nogroup --with-filename --all "))
      (list (read-shell-command "Run ack (like this): "
                                ack-command
                                'ack-history))))
  (let ((compilation-disable-input t))
    (compilation-start (concat command-args " < " null-device)
                       'grep-mode)))

;; package: bind-key

(require 'bind-key)

;; package: company

(require 'company)

(let ((bg (face-attribute 'default :background)))
  (custom-set-faces
    ;`(company-tooltip ((t (:inherit default :background ,(color-lighten-name bg 2)))))
    `(company-tooltip ((t (:inherit default :background ))))
    ;`(company-scrollbar-bg ((t (:background ,(color-lighten-name bg 10)))))
    ;`(company-scrollbar-fg ((t (:background ,(color-lighten-name bg 5)))))
    `(company-tooltip-selection ((t (:inherit font-lock-function-name-face))))
    `(company-tooltip-common ((t (:inherit font-lock-constant-face))))))

;; from https://github.com/company-mode/company-mode/issues/216
(defun company-complete-common-or-cycle ()
  (interactive)
  (when (company-manual-begin)
    (let ((tick (buffer-chars-modified-tick)))
      (call-interactively 'company-complete-common)
      (when (eq tick (buffer-chars-modified-tick))
        (let ((company-selection-wrap-around t))
          (call-interactively 'company-select-next))))))

(define-key company-active-map [tab] 'company-complete-common-or-cycle)
(define-key company-active-map (kbd "TAB") 'company-complete-common-or-cycle)

;; package: drag-stuff

(require 'drag-stuff)
(drag-stuff-mode t)

;; package: diminish

(require 'diminish)

;; package: elpy

(require 'elpy)

;; package: evil

(require 'evil)
(evil-mode 1)

;; package: expand-region

(require 'expand-region)

;; package: guide-key

(require 'guide-key)
(setq guide-key/idle-delay 0.5)
;(setq guide-key/guide-key-sequence '("C-c" "C-x r" "C-x 4"))
(setq guide-key/guide-key-sequence t)
(setq guide-key/recursive-key-sequence-flag t)
(setq guide-key/highlight-command-regexp
      '("rectangle"
        ("register" . font-lock-type-face)
        ("bookmark" . "hot pink")
        ("org-" . "orange")))
(guide-key-mode 1)

;; package: idle-highlight

(require 'idle-highlight-mode)

;; package: ido, ido-ubiquitous, flx-ido

(require 'ido)
(require 'ido-ubiquitous)
(require 'flx-ido)
(ido-mode t)
(ido-everywhere 1)
(ido-ubiquitous-mode 1)
(flx-ido-mode 1)
;; disable ido faces to see flx highlights.
(setq ido-enable-flex-matching t)
(setq ido-use-faces nil)

;; package: org

(require 'org)
(setq org-todo-keywords '((sequence "TODO" "IN-PROGRESS" "WAITING" "DONE")))
(setq org-list-allow-alphabetical 1)

;; package: popwin

(require 'popwin)
(popwin-mode 1)

;; package: projectile

(projectile-global-mode)

;; mode: python

(add-hook 'python-mode-hook
  (lambda ()
    (setq fill-column 78)
    (elpy-mode 1)
    ;;(fci-mode 1)
    (setq indent-tabs-mode t)
    (setq python-indent 4)
    (setq tab-width 4)
    (tabify (point-min) (point-max))))

;; package: smartparens

(require 'smartparens-config)

;; package: smex

(require 'smex)
(smex-initialize)

;; package: yasnippet

(require 'yasnippet)
(add-to-list 'yas-snippet-dirs "~/.emacs.d/snippets")
(add-to-list 'yas-snippet-dirs "~/.dotfiles/snippets")
(yas-global-mode 1)

;; keybindings: global

(bind-key "C-@" 'er/expand-region)
(define-key global-map (kbd "C-c a")       'org-agenda)
(define-key global-map (kbd "C-c b")       'org-iswitchb)
(define-key global-map (kbd "C-c c")       'org-capture)
(define-key global-map (kbd "C-c l")       'org-store-link)
(define-key global-map (kbd "C-c SPC")     'ace-jump-mode)
(define-key global-map (kbd "C-x SPC")     'ace-jump-mode-pop-mark)
(define-key global-map (kbd "M-x")         'smex)
(define-key global-map (kbd "M-X")         'smex-major-mode-commands)
(define-key global-map (kbd "C-c C-c M-x") 'execute-extended-command) ;; old M-x
;(define-key global-map (kbd "C-z")         popwin:keymap)

;; keybindings: evil

(bind-key "SPC" 'ace-jump-mode evil-normal-state-map)

;; keybindings: ido

;; adapted from http://whattheemacsd.com/setup-ido.el-02.html
(bind-key "~" (lambda () (interactive) (if (looking-back "/") (insert "~/") (call-interactively 'self-insert-command))) ido-file-completion-map)

;; keybindings: org

(setq org-agenda-custom-commands '(("f" occur-tree "FIXME"))) ;; C-c a f

;(define-key yas-minor-mode-map (kbd "<tab>") nil)
;(define-key yas-minor-mode-map (kbd "TAB") nil)
;(define-key yas-minor-mode-map (kbd "<backtab>") 'yas-expand)

#|
;; packages

(require 'package)
(package-initialize)

;; ... package archives

(add-to-list 'package-archives '("gnu" . "https://elpa.gnu.org/packages/") t)
(add-to-list 'package-archives '("marmalade" . "https://marmalade-repo.org/packages/") t)
;(add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/") t)
;(add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/") t)

;; ... packages to install

(defvar kyle/packages '(ace-jump-buffer
                        ace-jump-mode
                        ack
                        ;anaconda-mode
                        ;ag
                        ;auto-complete
                        ;better-defaults
                        ;color
                        ;color-theme
                        ;company
                        ;company-anaconda
                        ;diminish
                        elpy
                        evil
                        ;evil-indent-textobject
                        ;evil-leader
                        ;evil-matchit
                        ;evil-nerd-commenter
                        ;evil-paredit
                        ;evil-visualstar
                        ;exec-path-from-shell
                        fill-column-indicator
                        ;flx-ido
                        ;flycheck
                        ;flymake-cursor
                        ;git-gutter+
                        ;git-gutter-fringe+
                        ;guide-key
                        ;haskell-mode
                        ;ido-ubiquitous
                        ;ido-vertical-mode
                        jedi
                        ;magit
                        ;markdown-mode
                        ;molokai-theme
                        ;multiple-cursors
                        org
                        ;org-trello
                        ;paredit
                        ;popwin
                        ;pretty-mode
                        ;projectile
                        ;puppet-mode
                        ;python
                        python-environment
                        ;rainbow-delimiters
                        ;smart-mode-line
                        smex
                        ;surround
                        ;sublime-themes
                        undo-tree
                        ;vimrc-mode
                        ;yasnippet
                        ))

;; ... refresh package metadata

(when (not package-archive-contents)
  (package-refresh-contents))

;; ... install missing packages

(dolist (pkg kyle/packages)
  (when (and (not (package-installed-p pkg))
             (assoc pkg package-archive-contents))
    (package-install pkg)))

;(dolist (package kyle/packages)
;  (unless (package-installed-p package)
;    (package-install package)))

;; ... from http://stackoverflow.com/a/14838150/812472

(defun package-list-unaccounted-packages ()
  "Like `package-list-packages', but shows only the packages that
  are installed and are not in `jpk-packages'.  Useful for
  cleaning out unwanted packages."
  (interactive)
  (package-show-package-list
    (remove-if-not (lambda (x) (and (not (memq x kyle/packages))
                                    (not (package-built-in-p x))
                                    (package-installed-p x)))
                   (mapcar 'car package-archive-contents))))
|#

#|
;;
;; elpy
;;

(require 'elpy)

(setq elpy-rpc-backend "jedi")

(add-hook 'python-mode-hook
  (lambda ()
    (setq fill-column 78)
    (elpy-mode 1)
    (fci-mode 1)
    (setq indent-tabs-mode t)
    (setq python-indent 4)
    (setq tab-width 4)
    (tabify (point-min) (point-max))))

|#

#||
;;
;; company
;;

;;(global-company-mode 1)
;;(company-mode 1)
;;(add-to-list 'company-backends 'company-anaconda)

;(add-hook 'python-mode-hook
;  (lambda ()
;    (set (make-local-variable 'company-backends) '(company-anaconda))))

;(global-company-mode 1)

;;(require 'color)

;(let ((bg (face-attribute 'default :background)))
;  (custom-set-faces
;    `(company-tooltip ((t (:inherit default :background ,(color-lighten-name bg 2)))))
;    `(company-scrollbar-bg ((t (:background ,(color-lighten-name bg 10)))))
;    `(company-scrollbar-fg ((t (:background ,(color-lighten-name bg 5)))))
;    `(company-tooltip-selection ((t (:inherit font-lock-function-name-face))))
;    `(company-tooltip-common ((t (:inherit font-lock-constant-face))))))

(let ((bg (face-attribute 'default :background)))
  (custom-set-faces
    ;`(company-tooltip ((t (:inherit default :background ,(color-lighten-name bg 2)))))
    `(company-tooltip ((t (:inherit default :background ))))
    ;`(company-scrollbar-bg ((t (:background ,(color-lighten-name bg 10)))))
    ;`(company-scrollbar-fg ((t (:background ,(color-lighten-name bg 5)))))
    `(company-tooltip-selection ((t (:inherit font-lock-function-name-face))))
    `(company-tooltip-common ((t (:inherit font-lock-constant-face))))))

;(add-hook 'python-mode-hook 'jedi:setup)
;(setq jedi:complete-on-dot t)

;;(custom-set-variables
;; ;; custom-set-variables was added by Custom.
;; ;; If you edit it by hand, you could mess it up, so be careful.
;; ;; Your init file should contain only one such instance.
;; ;; If there is more than one, they won't work right.
;; ;;'(ansi-color-names-vector ["#242424" "#e5786d" "#95e454" "#cae682" "#8ac6f2" "#333366" "#ccaa8f" "#f6f3e8"])
;; '(company-auto-complete t)
;; '(company-auto-complete-chars (quote (32 95 40 41 46)))
;; '(company-show-numbers t)
;; '(custom-enabled-themes (quote (zenburn)))
;; '(custom-safe-themes (quote ("3b819bba57a676edf6e4881bd38c777f96d1aa3b3b5bc21d8266fa5b0d0f1ebf" default))))
;;(custom-set-faces
;; ;; custom-set-faces was added by Custom.
;; ;; If you edit it by hand, you could mess it up, so be careful.
;; ;; Your init file should contain only one such instance.
;; ;; If there is more than one, they won't work right.
;; '(company-tooltip ((t (:inherit default :background))))
;; '(company-tooltip-common ((t (:inherit font-lock-constant-face))))
;; '(company-tooltip-selection ((t (:inherit font-lock-function-name-face)))))
;(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
; '(ansi-color-names-vector ["#212526" "#ff4b4b" "#b4fa70" "#fce94f" "#729fcf" "#ad7fa8" "#8cc4ff" "#eeeeec"])
; '(custom-enabled-themes (quote (manoj-dark)))
; '(custom-safe-themes (quote ("1989847d22966b1403bab8c674354b4a2adf6e03e0ffebe097a6bd8a32be1e19" default))))
;(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
; '(default ((t (:background nil))))
; '(company-tooltip ((t (:inherit default :background))) t)
; '(company-tooltip-common ((t (:inherit font-lock-constant-face))) t)
; '(company-tooltip-selection ((t (:inherit font-lock-function-name-face))) t))

;;
;; theme
;;

;(require 'color-theme)
;(color-theme-initialize)

;(if window-system
;    (color-theme-subtle-hacker)
;    (color-theme-hober))

;(load-theme 'tty-dark t)
;(load-theme 'junio t)
;(load-theme 'renegade t)

;(color-theme-tty-dark)
;(color-theme-renegade)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(eldoc-idle-delay 0.25)
 '(org-agenda-files (quote ("~/wc/org/todo.org"))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:background nil))))
 '(company-tooltip ((t (:inherit default :background))))
 '(company-tooltip-common ((t (:inherit font-lock-constant-face))))
 '(company-tooltip-selection ((t (:inherit font-lock-function-name-face)))))

||#
