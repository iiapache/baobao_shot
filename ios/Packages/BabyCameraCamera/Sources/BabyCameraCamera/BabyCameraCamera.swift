/// BabyCameraCamera — 相机会话、取景 UI、实时滤镜、拍摄管线、元数据写入与相册导入（T2.5–T2.10）
///
/// 核心类型：`CameraSession`、`CameraViewController`、`OverlayView`、`PhotoCapturePipeline`、
/// `LivePhotoCapturer`、`BurstCapture`、`RealtimeFilterPipeline`、`CameraWatermarkHook`、
/// `MetadataWriter`、`ImportService`。
/// 依赖 `BabyCameraPermissions`（授权）、`BabyCameraImageKit`（HEIC/JPG/EXIF）、
/// `BabyCameraBaby`（`BabyAgeFormatter` / 信息浮层）、`Database`（photo 表）。
public enum BabyCameraCamera {
    public static let version = "0.3.0"
}
