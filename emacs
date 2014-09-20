;; vim: et sw=4 ts=4:

;; packages

(require 'package)
(package-initialize)

;; ... package archives

(add-to-list 'package-archives '("melpa" . "http://melpa.milkbox.net/packages/") t)
;(add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/") t)
;(add-to-list 'package-archives '("marmalade" . "http://marmalade-repo.org/packages/") t)
;(add-to-list 'package-archives '("gnu" . "http://elpa.gnu.org/packages/") t)

;; ... packages to install

(defvar kyle/packages '(ace-jump-buffer
                        ace-jump-mode
                        ack
                        ;anaconda-mode
                        ;ag
                        auto-complete
                        better-defaults
                        color
                        color-theme
                        company
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
                        flymake-cursor
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
                        sublime-themes
                        undo-tree
                        ;vimrc-mode
                        ;yasnippet
                        ))

;; ... refresh package metadata

(when (not package-archive-contents)
  (package-refresh-contents))

;; ... install missing packages

(dolist (package kyle/packages)
  (unless (package-installed-p package)
    (package-install package)))

;;
;; global editor options
;;

(global-font-lock-mode 1)
;(global-linum-mode 1)
(column-number-mode 1)
(line-number-mode 1)
(show-paren-mode 1)

(setq show-paren-style 'expression)

;; ===

;;
;; elpy
;;

(require 'elpy)

(setq elpy-rpc-backend "jedi")

(add-hook 'python-mode-hook
  (lambda ()
    (setq fill-column 78)
    (elpy-mode 1)
    (fci-mode 1)))

;;
;; evil
;;

;(require 'evil)

;(evil-mode 1)

;; ====

;;
;; ace-jump
;;

(require 'ace-jump-mode)

(eval-after-load "ace-jump-mode" '(ace-jump-mode-enable-mark-sync))

;;
;; ack
;;

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

;;
;; ido
;;

(ido-mode 1)

;;
;; smex
;;

(smex-initialize)

;;
;; key bindings
;;

(define-key global-map (kbd "C-c SPC") 'ace-jump-mode)
(define-key global-map (kbd "C-x SPC") 'ace-jump-mode-pop-mark)
(define-key evil-normal-state-map (kbd "SPC") 'ace-jump-mode)

(global-set-key (kbd "M-x") 'smex)
(global-set-key (kbd "M-X") 'smex-major-mode-commands)
(global-set-key (kbd "C-c C-c M-x") 'execute-extended-command)

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

(require 'color-theme)
(color-theme-initialize)

(if window-system
    (color-theme-subtle-hacker)
    (color-theme-hober))

;(load-theme 'tty-dark t)
;(load-theme 'junio t)
;(load-theme 'renegade t)

;(color-theme-tty-dark)
;(color-theme-renegade)
