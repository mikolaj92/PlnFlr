#if os(iOS)
import AVFoundation
import RoomPlan
import SwiftUI
import UIKit

/// Apple owns camera coaching, reconstruction and the post-capture model preview.
struct RoomScannerView: UIViewControllerRepresentable {
    var onSave: (Data) -> Void
    var onCancel: () -> Void
    var onFailure: (String) -> Void

    func makeUIViewController(context: Context) -> RoomScannerController {
        RoomScannerController(onSave: onSave, onCancel: onCancel, onFailure: onFailure)
    }

    func updateUIViewController(_ controller: RoomScannerController, context: Context) {}

    static func dismantleUIViewController(_ controller: RoomScannerController, coordinator: ()) {
        controller.shutdown()
    }
}

final class RoomScannerController: UIViewController, @preconcurrency RoomCaptureViewDelegate {
    private let onSave: (Data) -> Void
    private let onCancel: () -> Void
    private let onFailure: (String) -> Void
    private var captureView: RoomCaptureView?
    private var source: Data?
    private var closed = false
    private var permissionTask: Task<Void, Never>?
    private let status = UILabel()
    private let finishButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)

    init(onSave: @escaping (Data) -> Void, onCancel: @escaping () -> Void, onFailure: @escaping (String) -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel
        self.onFailure = onFailure
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(onSave:onCancel:onFailure:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let cancel = UIButton(type: .system)
        cancel.setTitle("Anuluj", for: .normal)
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        finishButton.setTitle("Zakończ skan", for: .normal)
        finishButton.addTarget(self, action: #selector(finishTapped), for: .touchUpInside)
        finishButton.isEnabled = false
        saveButton.setTitle("Zapisz skan", for: .normal)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.isEnabled = false
        status.text = "Przygotowanie aparatu…"
        status.numberOfLines = 0
        status.textAlignment = .center
        let controls = UIStackView(arrangedSubviews: [cancel, finishButton, saveButton])
        controls.distribution = .fillEqually
        let header = UIStackView(arrangedSubviews: [status, controls])
        header.axis = .vertical
        header.spacing = 12
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            controls.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        guard RoomCaptureSession.isSupported else {
            fail("Skanowanie wymaga iPhone’a lub iPada z obsługą RoomPlan i LiDAR. Możesz zaimportować skan USDZ.")
            return
        }
        permissionTask = Task { [weak self] in
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            guard let self, !self.closed, !Task.isCancelled else { return }
            guard allowed else {
                self.fail("Brak dostępu do aparatu. Włącz go w Ustawieniach, aby skanować pokój.")
                return
            }
            let capture = RoomCaptureView(frame: .zero)
            capture.delegate = self
            capture.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(capture)
            NSLayoutConstraint.activate([
                capture.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
                capture.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                capture.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                capture.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
            ])
            self.captureView = capture
            self.status.text = "Skanuj jedno pomieszczenie, zgodnie ze wskazówkami aparatu."
            self.finishButton.isEnabled = true
            capture.captureSession.run(configuration: .init())
        }
    }

    @objc private func finishTapped() {
        finishButton.isEnabled = false
        status.text = "Przetwarzanie skanu…"
        captureView?.captureSession.stop()
    }

    @objc private func saveTapped() {
        guard let source, !closed else { return }
        shutdown()
        onSave(source)
    }

    @objc private func cancelTapped() {
        guard !closed else { return }
        shutdown()
        onCancel()
    }

    func shutdown() {
        guard !closed else { return }
        closed = true
        permissionTask?.cancel()
        captureView?.delegate = nil
        captureView?.captureSession.stop()
    }

    private func fail(_ message: String) {
        guard !closed else { return }
        shutdown()
        onFailure(message)
    }

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: (any Error)?) -> Bool {
        guard !closed else { return false }
        if let error { fail(error.localizedDescription); return false }
        return true
    }

    func captureView(didPresent processedResult: RoomPlan.CapturedRoom, error: (any Error)?) {
        guard !closed else { return }
        if let error { fail(error.localizedDescription); return }
        do {
            source = try JSONEncoder().encode(processedResult)
            status.text = "Sprawdź model. Zapisujemy pełny skan; zamiana na podłogi będzie kolejnym krokiem."
            saveButton.isEnabled = true
        } catch {
            fail("Nie udało się przygotować zapisu skanu: \(error.localizedDescription)")
        }
    }
}
#endif
