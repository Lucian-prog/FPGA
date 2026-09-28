import argparse
from src.stream_analyzer import Stream_Analyzer
import time

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--device', type=int, default=None, dest='device',
                        help='pyaudio (portaudio) device index')
    parser.add_argument('--height', type=int, default=450, dest='height',
                        help='height, in pixels, of the visualizer window')
    parser.add_argument('--n_frequency_bins', type=int, default=400, dest='frequency_bins',
                        help='The FFT features are grouped in bins')
    parser.add_argument('--verbose', action='store_true')
    parser.add_argument('--window_ratio', default='24/9', dest='window_ratio',
                        help='float ratio of the visualizer window. e.g. 24/9')

    # 可调参数：窗口大小、刷新率、平滑程度等等
    parser.add_argument(
        '--fft_window_ms',
        type=int,
        default=150, 
        dest='fft_window_ms',
        help='FFT window size in ms (larger = smoother, less sensitive)'
    )
    parser.add_argument(
        '--updates_per_second',
        type=int,
        default=60,   # 保持 60，已经足够
        dest='updates_per_second',
        help='How often to read the audio stream (lower = less jitter)'
    )
    parser.add_argument(
        '--smoothing_ms',
        type=int,
        default=300,  # 原来 200 -> 现在 300，明显更平滑
        dest='smoothing_ms',
        help='Temporal smoothing length in ms (larger = smoother, less sensitive)'
    )
    parser.add_argument(
        '--fps',
        type=int,
        default=120,  # 按你要求，视觉帧率提高到 120
        dest='fps',
        help='How often to update FFT features + display (visual FPS)'
    )
    parser.add_argument(
        '--sleep_between_frames',
        dest='sleep_between_frames',
        action='store_true',
        help='when true process sleeps between frames to reduce CPU usage'
    )
    return parser.parse_args()

def convert_window_ratio(window_ratio):
    if '/' in window_ratio:
        dividend, divisor = window_ratio.split('/')
        try:
            float_ratio = float(dividend) / float(divisor)
        except:
            raise ValueError('window_ratio should be in the format: float/float')
        return float_ratio
    raise ValueError('window_ratio should be in the format: float/float')

def run_FFT_analyzer():
    args = parse_args()
    window_ratio = convert_window_ratio(args.window_ratio)

    ear = Stream_Analyzer(
        device = args.device,                    # Pyaudio device index, defaults to first mic input
        rate   = None,                           # Audio samplerate, None uses the default source settings
        FFT_window_size_ms  = args.fft_window_ms,# 现在默认 150ms，更平滑
        updates_per_second  = args.updates_per_second,  # 默认 60
        smoothing_length_ms = args.smoothing_ms,        # 现在默认 300ms，更平滑
        n_frequency_bins    = args.frequency_bins,      # FFT 分箱
        visualize           = 1,                        # 用 PyGame 可视化
        verbose             = args.verbose,             # 打印调试信息
        height              = args.height,              # 窗口高度
        window_ratio        = window_ratio              # 窗口宽高比
    )

    # 外层显示 FPS：提高到 120
    fps = args.fps
    last_update = time.time()
    print("All ready, starting audio measurements now...")
    fft_samples = 0

    while True:
        if (time.time() - last_update) > (1.0 / fps):
            last_update = time.time()
            # 这一步会拉取音频特征并触发内部可视化刷新
            raw_fftx, raw_fft, binned_fftx, binned_fft = ear.get_audio_features()
            fft_samples += 1
            # if fft_samples % 20 == 0:
            #     print(f"Got fft_features #{fft_samples} of shape {raw_fft.shape}")
        elif args.sleep_between_frames:
            # 降一点 CPU：只有你在命令行加 --sleep_between_frames 时才生效
            sleep_time = (1.0 / fps) - (time.time() - last_update)
            if sleep_time > 0:
                time.sleep(sleep_time * 0.99)

if __name__ == '__main__':
    run_FFT_analyzer()