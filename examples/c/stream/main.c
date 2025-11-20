// 实时转写 C 示例：通过 PortAudio 采集麦克风音频并写入 FFI WebSocket
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <portaudio.h>

#include "../../../include/dianyaapi_ffi.h"

#define TOKEN                                                                 \
    "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyXzgzZTk5Y2YyIiwiZXhwIjoxNzY1MzU5Mjc4Ljk0ODk5fQ.JVL2o7u2IC-LhqFvSAmfE9oGVmnL7R4vfnxm_JA0V5k"

#define AUDIO_SAMPLE_RATE 16000
#define AUDIO_CHANNELS 1
#define AUDIO_FORMAT paInt16
#define BYTES_PER_SAMPLE 2
#define CHUNK_DURATION_SECONDS 0.2
#define QUEUE_MAX_CHUNKS 50
#define RECV_BUFFER_BYTES 32768

static const size_t CHUNK_SIZE_BYTES =
    (size_t)(AUDIO_SAMPLE_RATE * AUDIO_CHANNELS * BYTES_PER_SAMPLE *
             CHUNK_DURATION_SECONDS);
static const size_t FRAMES_PER_BUFFER =
    (size_t)(AUDIO_SAMPLE_RATE * CHUNK_DURATION_SECONDS);

typedef struct {
    size_t size;
    uint8_t data[65536];
} AudioChunk;

typedef struct {
    AudioChunk buffer[QUEUE_MAX_CHUNKS];
    size_t head;
    size_t tail;
    size_t count;
    bool closed;
    pthread_mutex_t mutex;
    pthread_cond_t cond_nonempty;
    pthread_cond_t cond_nonfull;
} AudioQueue;

typedef struct {
    AudioQueue *queue;
} CaptureContext;

typedef struct {
    AudioQueue *queue;
    struct TranscribeStream *handle;
} PumpContext;

typedef struct {
    struct TranscribeStream *handle;
} ReceiveContext;

static volatile sig_atomic_t g_should_stop = 0;

static void log_line(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    fprintf(stderr, "\n");
    va_end(args);
}

static void signal_handler(int sig) {
    (void)sig;
    g_should_stop = 1;
    log_line("检测到 Ctrl+C, 正在清理...");
}

static void audio_queue_init(AudioQueue *queue) {
    memset(queue, 0, sizeof(*queue));
    pthread_mutex_init(&queue->mutex, NULL);
    pthread_cond_init(&queue->cond_nonempty, NULL);
    pthread_cond_init(&queue->cond_nonfull, NULL);
}

static void audio_queue_close(AudioQueue *queue) {
    pthread_mutex_lock(&queue->mutex);
    queue->closed = true;
    pthread_cond_broadcast(&queue->cond_nonempty);
    pthread_cond_broadcast(&queue->cond_nonfull);
    pthread_mutex_unlock(&queue->mutex);
}

static bool audio_queue_push(AudioQueue *queue, const uint8_t *data,
                             size_t size) {
    pthread_mutex_lock(&queue->mutex);
    while (queue->count == QUEUE_MAX_CHUNKS && !queue->closed) {
        pthread_cond_wait(&queue->cond_nonfull, &queue->mutex);
    }
    if (queue->closed) {
        pthread_mutex_unlock(&queue->mutex);
        return false;
    }
    AudioChunk *chunk = &queue->buffer[queue->tail];
    chunk->size = size > sizeof(chunk->data) ? sizeof(chunk->data) : size;
    memcpy(chunk->data, data, chunk->size);
    queue->tail = (queue->tail + 1) % QUEUE_MAX_CHUNKS;
    queue->count++;
    pthread_cond_signal(&queue->cond_nonempty);
    pthread_mutex_unlock(&queue->mutex);
    return true;
}

static bool audio_queue_pop(AudioQueue *queue, AudioChunk *out_chunk) {
    pthread_mutex_lock(&queue->mutex);
    while (queue->count == 0 && !queue->closed) {
        pthread_cond_wait(&queue->cond_nonempty, &queue->mutex);
    }
    if (queue->count == 0 && queue->closed) {
        pthread_mutex_unlock(&queue->mutex);
        return false;
    }
    AudioChunk *chunk = &queue->buffer[queue->head];
    *out_chunk = *chunk;
    queue->head = (queue->head + 1) % QUEUE_MAX_CHUNKS;
    queue->count--;
    pthread_cond_signal(&queue->cond_nonfull);
    pthread_mutex_unlock(&queue->mutex);
    return true;
}

static double now_seconds(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

static bool ffi_call_ok(const char *action, int code, FfiError *error) {
    if (code == 0) {
        return true;
    }
    const char *msg = (error && error->message) ? error->message : "unknown";
    log_line("%s 失败 (code=%d): %s", action, code, msg);
    if (error && error->message) {
        transcribe_ffi_free_error(error);
        error->message = NULL;
    }
    return false;
}

static void *capture_thread(void *arg) {
    CaptureContext *ctx = (CaptureContext *)arg;
    PaStream *stream = NULL;
    PaError pa_err = Pa_OpenDefaultStream(&stream, AUDIO_CHANNELS, 0,
                                          AUDIO_FORMAT, AUDIO_SAMPLE_RATE,
                                          FRAMES_PER_BUFFER, NULL, NULL);
    if (pa_err != paNoError) {
        log_line("打开音频输入失败: %s", Pa_GetErrorText(pa_err));
        g_should_stop = 1;
        audio_queue_close(ctx->queue);
        return NULL;
    }

    pa_err = Pa_StartStream(stream);
    if (pa_err != paNoError) {
        log_line("启动音频流失败: %s", Pa_GetErrorText(pa_err));
        g_should_stop = 1;
        audio_queue_close(ctx->queue);
        Pa_CloseStream(stream);
        return NULL;
    }

    log_line("音频采集线程已启动");
    int16_t capture_buffer[FRAMES_PER_BUFFER];
    while (!g_should_stop) {
        pa_err = Pa_ReadStream(stream, capture_buffer, FRAMES_PER_BUFFER);
        if (pa_err != paNoError) {
            log_line("读取音频失败: %s", Pa_GetErrorText(pa_err));
            break;
        }
        if (!audio_queue_push(ctx->queue, (const uint8_t *)capture_buffer,
                              FRAMES_PER_BUFFER * BYTES_PER_SAMPLE)) {
            break;
        }
    }

    log_line("音频采集线程停止");
    audio_queue_close(ctx->queue);
    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    return NULL;
}

static void flush_bytes(struct TranscribeStream *handle, const uint8_t *data,
                        size_t len) {
    if (len == 0) {
        return;
    }
    FfiError error = {0};
    if (!ffi_call_ok("发送音频", transcribe_ffi_ws_write_bytes(handle, data, len, &error),
                     &error)) {
        g_should_stop = 1;
    }
}

static void *pump_thread(void *arg) {
    PumpContext *ctx = (PumpContext *)arg;
    uint8_t buffer[CHUNK_SIZE_BYTES * 4];
    size_t buffered = 0;
    double next_flush = now_seconds() + CHUNK_DURATION_SECONDS;

    log_line("音频发送线程已启动");

    while (!g_should_stop) {
        AudioChunk chunk = {0};
        if (!audio_queue_pop(ctx->queue, &chunk)) {
            break;
        }

        if (buffered + chunk.size > sizeof(buffer)) {
            flush_bytes(ctx->handle, buffer, buffered);
            buffered = 0;
        }
        memcpy(buffer + buffered, chunk.data, chunk.size);
        buffered += chunk.size;

        while (buffered >= CHUNK_SIZE_BYTES) {
            flush_bytes(ctx->handle, buffer, CHUNK_SIZE_BYTES);
            memmove(buffer, buffer + CHUNK_SIZE_BYTES, buffered - CHUNK_SIZE_BYTES);
            buffered -= CHUNK_SIZE_BYTES;
        }

        double current = now_seconds();
        if (buffered > 0 && current >= next_flush) {
            flush_bytes(ctx->handle, buffer, buffered);
            buffered = 0;
            next_flush = current + CHUNK_DURATION_SECONDS;
        }
    }

    if (buffered > 0) {
        flush_bytes(ctx->handle, buffer, buffered);
    }

    log_line("音频发送线程停止");
    return NULL;
}

static void *receive_thread(void *arg) {
    ReceiveContext *ctx = (ReceiveContext *)arg;
    char buffer[RECV_BUFFER_BYTES];
    log_line("消息接收线程已启动");
    while (!g_should_stop) {
        memset(buffer, 0, sizeof(buffer));
        uintptr_t buf_len = sizeof(buffer);
        FfiError error = {0};
        int code = transcribe_ffi_ws_receive(ctx->handle, buffer, &buf_len, 200, &error);
        if (code != 0) {
            if (!ffi_call_ok("接收消息", code, &error)) {
                break;
            }
            continue;
        }
        if (buf_len == 0) {
            continue;
        }
        printf("%s\n", buffer);
        fflush(stdout);
    }
    log_line("消息接收线程停止");
    return NULL;
}

static void cleanup_stream(struct TranscribeStream **handle) {
    if (!handle || !*handle) {
        return;
    }
    FfiError error = {0};
    ffi_call_ok("停止 WebSocket", transcribe_ffi_ws_stop(*handle, &error), &error);
    transcribe_ffi_ws_free(*handle);
    *handle = NULL;
}

int main(void) {
    signal(SIGINT, signal_handler);
    log_line("实时转写示例启动");

    if (Pa_Initialize() != paNoError) {
        log_line("初始化 PortAudio 失败");
        return 1;
    }

    AudioQueue queue;
    audio_queue_init(&queue);

    FfiError error = {0};
    FfiSessionCreator session = {0};
    if (!ffi_call_ok("创建会话",
                     transcribe_ffi_create_session("speed", TOKEN, &session, &error),
                     &error)) {
        Pa_Terminate();
        return 1;
    }
    log_line("会话创建成功: task_id=%s session_id=%s", session.task_id,
             session.session_id);

    struct TranscribeStream *handle = NULL;
    if (!ffi_call_ok("创建 WebSocket", transcribe_ffi_ws_create(session.session_id, &handle,
                                                               &error),
                     &error)) {
        transcribe_ffi_free_session_creator(&session);
        Pa_Terminate();
        return 1;
    }

    if (!ffi_call_ok("启动 WebSocket", transcribe_ffi_ws_start(handle, &error), &error)) {
        cleanup_stream(&handle);
        transcribe_ffi_free_session_creator(&session);
        Pa_Terminate();
        return 1;
    }

    CaptureContext capture_ctx = {.queue = &queue};
    PumpContext pump_ctx = {.queue = &queue, .handle = handle};
    ReceiveContext recv_ctx = {.handle = handle};

    pthread_t capture_tid, pump_tid, recv_tid;
    pthread_create(&capture_tid, NULL, capture_thread, &capture_ctx);
    pthread_create(&pump_tid, NULL, pump_thread, &pump_ctx);
    pthread_create(&recv_tid, NULL, receive_thread, &recv_ctx);

    pthread_join(capture_tid, NULL);
    audio_queue_close(&queue);
    pthread_join(pump_tid, NULL);
    g_should_stop = 1;
    pthread_join(recv_tid, NULL);

    cleanup_stream(&handle);

    if (session.task_id) {
        FfiSessionEnder ender = {0};
        if (ffi_call_ok("关闭会话",
                        transcribe_ffi_close_session(session.task_id, TOKEN, 0, &ender,
                                                     &error),
                        &error)) {
            log_line("会话关闭状态: %s", ender.status ? ender.status : "unknown");
        }
        transcribe_ffi_free_session_ender(&ender);
        transcribe_ffi_free_session_creator(&session);
    }

    Pa_Terminate();
    log_line("示例结束");
    return 0;
}
