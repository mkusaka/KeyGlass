import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

enum SensitiveInputSuppressionReason: String, Equatable {
    case secureEventInput = "secure-event-input"
    case secureTextField = "secure-text-field"
}

@MainActor
protocol SensitiveInputDetecting {
    func currentSuppressionReason() -> SensitiveInputSuppressionReason?
}

struct NoOpSensitiveInputDetector: SensitiveInputDetecting {
    func currentSuppressionReason() -> SensitiveInputSuppressionReason? {
        nil
    }
}

struct StubSensitiveInputDetector: SensitiveInputDetecting {
    let reason: SensitiveInputSuppressionReason?

    func currentSuppressionReason() -> SensitiveInputSuppressionReason? {
        reason
    }
}

@MainActor
final class SystemSensitiveInputDetector: SensitiveInputDetecting {
    private static let secureTextFieldSubrole = NSAccessibility.Subrole.secureTextField.rawValue
    private static let maxAncestorTraversalDepth = 6

    func currentSuppressionReason() -> SensitiveInputSuppressionReason? {
        if IsSecureEventInputEnabled() {
            return .secureEventInput
        }

        guard AXIsProcessTrusted(), let focusedElement = focusedElement() else {
            return nil
        }

        return containsSecureTextFieldSubrole(startingAt: focusedElement) ? .secureTextField : nil
    }

    private func focusedElement() -> AXUIElement? {
        elementAttribute(kAXFocusedUIElementAttribute as CFString, from: AXUIElementCreateSystemWide())
    }

    private func containsSecureTextFieldSubrole(startingAt element: AXUIElement) -> Bool {
        var currentElement: AXUIElement? = element
        var remainingDepth = Self.maxAncestorTraversalDepth

        while remainingDepth >= 0, let unwrappedElement = currentElement {
            if stringAttribute(kAXSubroleAttribute as CFString, from: unwrappedElement) == Self.secureTextFieldSubrole {
                return true
            }

            currentElement = elementAttribute(kAXParentAttribute as CFString, from: unwrappedElement)
            remainingDepth -= 1
        }

        return false
    }

    private func stringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }

        return value as? String
    }

    private func elementAttribute(_ attribute: CFString, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        return unsafeBitCast(value, to: AXUIElement.self)
    }
}
