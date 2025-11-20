package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"os/signal"
	"time"

	"dianyaapi"
)

const (
	defaultToken   = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyXzgzZTk5Y2YyIiwiZXhwIjoxNzY1MzU5Mjc4Ljk0ODk5fQ.JVL2o7u2IC-LhqFvSAmfE9oGVmnL7R4vfnxm_JA0V5k"
	defaultTaskID  = "tfile_e50e3ee3"
	defaultWavFile = "/home/arch/Workspace/RustProjects/dianya_api_sdk/data/one_sentence.wav"

	chunkDuration = 200 * time.Millisecond
	sampleRate    = 16000
	channels      = 1
	bytesPerSamp  = 2 // int16
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	client := dianyaapi.NewClient()
	token := defaultToken

	if err := runRestExamples(ctx, client, token); err != nil {
		log.Fatalf("REST examples failed: %v", err)
	}

	if err := runStreamExample(ctx, token); err != nil {
		log.Fatalf("stream example failed: %v", err)
	}
}

func runRestExamples(ctx context.Context, client *dianyaapi.Client, token string) error {
	log.Println("示例 1: 上传音频文件")
	uploadResp, err := client.Upload(token, absPath(defaultWavFile), false, false, "quality")
	if err != nil {
		return fmt.Errorf("upload: %w", err)
	}
	if uploadResp.TaskID != "" {
		log.Printf("普通转写模式，任务ID: %s", uploadResp.TaskID)
	} else {
		log.Printf("一句话模式，status=%s message=%s", uploadResp.Status, uploadResp.Message)
	}

	taskID := defaultTaskID
	if taskID == "" && uploadResp.TaskID != "" {
		// 若未预置任务 ID，则使用刚上传任务
		taskID = uploadResp.TaskID
		log.Printf("使用新任务 ID 进行后续操作: %s", taskID)
	} else if taskID != uploadResp.TaskID && uploadResp.TaskID != "" {
		log.Printf("继续使用预置任务 %s 以确保资源已准备好（最新上传任务 %s）", taskID, uploadResp.TaskID)
	}

	if taskID == "" {
		log.Println("未获取任务 ID，跳过后续示例")
		return nil
	}

	log.Println("示例 2: 获取转写任务状态")
	statusResp, err := client.GetStatus(token, taskID, "")
	if err != nil {
		return fmt.Errorf("status: %w", err)
	}
	log.Printf("任务状态: %s", statusResp.Status)

	log.Println("示例 3: 获取分享链接")
	shareResp, err := client.GetShareLink(token, taskID, 7)
	if err != nil {
		return fmt.Errorf("share link: %w", err)
	}
	log.Printf("分享链接: %s (过期: %s)", shareResp.ShareURL, shareResp.ExpiredAt)

	log.Println("示例 4: 导出转写结果")
	exportData, err := client.Export(token, taskID, "transcript", "pdf")
	if err != nil {
		return fmt.Errorf("export: %w", err)
	}
	log.Printf("导出成功，大小 %d 字节", len(exportData))

	log.Println("示例 5: 翻译转写任务")
	transResp, err := client.TranslateTranscribe(token, taskID, "en")
	if err != nil {
		return fmt.Errorf("translate transcribe: %w", err)
	}
	log.Printf("翻译任务状态: %s", transResp.Status)

	log.Println("示例 6: 翻译文本")
	textResp, err := client.TranslateText(token, "Hello, world!", "zh")
	if err != nil {
		return fmt.Errorf("translate text: %w", err)
	}
	log.Printf("翻译结果: %s", textResp.Data)

	return ctx.Err()
}

func runStreamExample(ctx context.Context, token string) error {
	log.Println("示例 7: 实时转写（读取 WAV 文件模拟音频流）")
	session, err := dianyaapi.CreateSession("speed", token)
	if err != nil {
		return fmt.Errorf("create session: %w", err)
	}
	log.Printf("会话创建成功: task_id=%s session_id=%s", session.TaskID, session.SessionID)

	stream, err := dianyaapi.NewStream(session.SessionID)
	if err != nil {
		return fmt.Errorf("new stream: %w", err)
	}
	defer stream.Close()

	if err := stream.Start(); err != nil {
		return fmt.Errorf("stream start: %w", err)
	}

	audio, err := os.Open(absPath(defaultWavFile))
	if err != nil {
		return fmt.Errorf("open wav: %w", err)
	}
	defer audio.Close()

	chunkBytes := sampleRate * channels * bytesPerSamp * int(chunkDuration/time.Second)
	if chunkBytes == 0 {
		chunkBytes = 3200 // fallback for 0.2s chunks
	}

	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	errCh := make(chan error, 1)
	go func() {
		buf := make([]byte, chunkBytes)
		for {
			n, readErr := io.ReadFull(audio, buf)
			if readErr == io.ErrUnexpectedEOF || readErr == io.EOF {
				if n > 0 {
					_ = stream.SendBytes(buf[:n])
				}
				break
			}
			if readErr != nil {
				errCh <- fmt.Errorf("read audio: %w", readErr)
				return
			}
			if err := stream.SendBytes(buf[:n]); err != nil {
				errCh <- fmt.Errorf("send bytes: %w", err)
				return
			}
			select {
			case <-ctx.Done():
				errCh <- ctx.Err()
				return
			case <-time.After(chunkDuration / 2):
			}
		}
		errCh <- nil
	}()

recvLoop:
	for {
		select {
		case err := <-errCh:
			if err != nil {
				return err
			}
			break recvLoop
		default:
			msg, ok, err := stream.Receive(500 * time.Millisecond)
			if err != nil {
				return fmt.Errorf("receive: %w", err)
			}
			if ok {
				log.Printf("WS消息: %s", msg)
			}
		}
	}

	closeResp, err := dianyaapi.CloseSession(session.TaskID, token, 0)
	if err != nil {
		return fmt.Errorf("close session: %w", err)
	}
	log.Printf("会话关闭状态: %s", closeResp.Status)
	return nil
}

func absPath(p string) string { return p }
