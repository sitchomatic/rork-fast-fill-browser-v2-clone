import Foundation

struct JavaScriptInjectionService {
    static func fillHelperScript() -> String {
        return """
        window.__ffb_setNativeValue = function(element, value) {
            const nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
            nativeInputValueSetter.call(element, value);
            element.dispatchEvent(new Event('input', { bubbles: true }));
            element.dispatchEvent(new Event('change', { bubbles: true }));
        };

        window.__ffb_findUsername = function(customSel) {
            if (customSel) {
                const el = document.querySelector(customSel);
                if (el) return el;
            }
            const selectors = [
                'input[autocomplete="username"]',
                'input[autocomplete="email"]',
                'input[type="email"]',
                'input[name*="user" i]',
                'input[name*="email" i]',
                'input[name*="login" i]',
                'input[id*="user" i]',
                'input[id*="email" i]',
                'input[id*="login" i]',
                'input[placeholder*="email" i]',
                'input[placeholder*="user" i]',
                'input[type="text"]'
            ];
            for (const sel of selectors) {
                const el = document.querySelector(sel);
                if (el && el.offsetParent !== null) return el;
            }
            return null;
        };

        window.__ffb_findPassword = function(customSel) {
            if (customSel) {
                const el = document.querySelector(customSel);
                if (el) return el;
            }
            const selectors = [
                'input[autocomplete="current-password"]',
                'input[type="password"]',
                'input[name*="pass" i]',
                'input[id*="pass" i]'
            ];
            for (const sel of selectors) {
                const el = document.querySelector(sel);
                if (el && el.offsetParent !== null) return el;
            }
            return null;
        };

        window.__ffb_findSubmit = function(customSel) {
            if (customSel) {
                const el = document.querySelector(customSel);
                if (el) return el;
            }
            const selectors = [
                'button[type="submit"]',
                'input[type="submit"]',
                'button[name*="login" i]',
                'button[name*="sign" i]',
                'button[id*="login" i]',
                'button[id*="sign" i]',
                'button:has(> span)',
                '[role="button"]'
            ];
            for (const s of selectors) {
                const els = document.querySelectorAll(s);
                for (const el of els) {
                    if (el.offsetParent !== null) {
                        const text = (el.textContent || '').toLowerCase();
                        if (text.includes('log in') || text.includes('login') ||
                            text.includes('sign in') || text.includes('signin') ||
                            text.includes('submit') || text.includes('continue') ||
                            text.includes('next')) {
                            return el;
                        }
                    }
                }
            }
            const form = document.querySelector('form');
            if (form) {
                const btn = form.querySelector('button, input[type="submit"]');
                if (btn) return btn;
            }
            return null;
        };
        """
    }

    static func fillCredentialScript(
        username: String,
        password: String,
        usernameSelector: String?,
        passwordSelector: String?
    ) -> String {
        let escapedUser = username.jsEscaped
        let escapedPass = password.jsEscaped
        let userSel = (usernameSelector?.isEmpty == false) ? usernameSelector!.jsEscaped : ""
        let passSel = (passwordSelector?.isEmpty == false) ? passwordSelector!.jsEscaped : ""

        return """
        (function() {
            const userField = window.__ffb_findUsername ? window.__ffb_findUsername('\(userSel)') : null;
            const passField = window.__ffb_findPassword ? window.__ffb_findPassword('\(passSel)') : null;
            const setVal = window.__ffb_setNativeValue || function(el, v) { el.value = v; el.dispatchEvent(new Event('input', {bubbles:true})); };
            let filled = 0;
            if (userField) { userField.focus(); setVal(userField, '\(escapedUser)'); filled++; }
            if (passField) { passField.focus(); setVal(passField, '\(escapedPass)'); filled++; }
            return JSON.stringify({ filled: filled, userFound: !!userField, passFound: !!passField });
        })();
        """
    }

    static func submitFormScript(submitSelector: String?) -> String {
        let sel = (submitSelector?.isEmpty == false) ? submitSelector!.jsEscaped : ""

        return """
        (function() {
            const btn = window.__ffb_findSubmit ? window.__ffb_findSubmit('\(sel)') : null;
            if (btn) { btn.click(); return JSON.stringify({ submitted: true }); }
            const form = document.querySelector('form');
            if (form) { form.submit(); return JSON.stringify({ submitted: true, method: 'form' }); }
            return JSON.stringify({ submitted: false });
        })();
        """
    }

    static func detectLoginFormScript() -> String {
        return """
        (function() {
            const passFields = document.querySelectorAll('input[type="password"]');
            let hasVisible = false;
            passFields.forEach(f => { if (f.offsetParent !== null) hasVisible = true; });
            const forms = document.querySelectorAll('form');
            let formCount = 0;
            forms.forEach(f => { if (f.querySelector('input[type="password"]')) formCount++; });
            return JSON.stringify({
                hasLoginForm: hasVisible,
                passwordFieldCount: passFields.length,
                loginFormCount: formCount
            });
        })();
        """
    }

    static func extractFilledCredentialsScript() -> String {
        return """
        (function() {
            const passField = document.querySelector('input[type="password"]');
            if (!passField || !passField.value) return JSON.stringify({ found: false });
            let userField = null;
            const form = passField.closest('form');
            if (form) { userField = form.querySelector('input[type="email"], input[type="text"], input[autocomplete="username"]'); }
            if (!userField) { userField = document.querySelector('input[type="email"], input[autocomplete="username"]'); }
            return JSON.stringify({ found: true, username: userField ? userField.value : '', password: passField.value });
        })();
        """
    }
}

extension String {
    var jsEscaped: String {
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
