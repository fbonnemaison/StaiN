import AppKit
import ObjectiveC

/// Guardado clásico: al cerrar (o salir) con cambios sin guardar, se pregunta Guardar / No guardar / Cancelar.
///
/// `DocumentGroup` usa por debajo subclases privadas de `NSDocument` (`SwiftUI.PlatformDocument` y una
/// subclase genérica creada al vuelo) con autoguardado en el sitio, que escribe los cambios en el archivo
/// original al cerrarlo sin preguntar. Como no se pueden sobrescribir, se fuerza `autosavesInPlace = false`
/// en `NSDocument` y en cada clase de la cadena del documento en cuanto aparece su ventana.
@MainActor
enum ClassicSaving {
    private static var patched: Set<ObjectIdentifier> = []
    private static var observer: NSObjectProtocol?

    /// Llamar antes de que se abra ningún documento (`applicationWillFinishLaunching`).
    static func install() {
        patchHierarchy(of: NSDocument.self)
        for name in ["SwiftUI.PlatformDocument", "SwiftUI.FileWrapperPlatformDocument"] {
            if let cls = NSClassFromString(name) { patchHierarchy(of: cls) }
        }
        // La subclase concreta se crea al abrir el primer documento: se parchea al mostrarse su ventana,
        // siempre antes de que el usuario pueda cerrarla.
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { notification in
            let window = notification.object as? NSWindow
            MainActor.assumeIsolated {
                guard let document = window?.windowController?.document as? NSDocument else { return }
                patchHierarchy(of: type(of: document))
            }
        }
    }

    /// Hace que `autosavesInPlace` devuelva `false` en `cls` y en sus superclases hasta `NSDocument`.
    private static func patchHierarchy(of cls: AnyClass) {
        let selector = #selector(getter: NSDocument.autosavesInPlace)
        var current: AnyClass? = cls
        while let candidate = current {
            if patched.insert(ObjectIdentifier(candidate)).inserted, let meta = object_getClass(candidate) {
                class_replaceMethod(meta, selector, falseImplementation, "B@:")
            }
            if candidate == NSDocument.self { break }
            current = class_getSuperclass(candidate)
        }
    }

    private static let falseImplementation: IMP = {
        let block: @convention(block) (AnyClass) -> Bool = { _ in false }
        return imp_implementationWithBlock(block)
    }()
}
