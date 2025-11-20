#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../../../include/dianyaapi_ffi.h"

int main() {
    const char* token = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyXzgzZTk5Y2YyIiwiZXhwIjoxNzY1MzU5Mjc4Ljk0ODk5fQ.JVL2o7u2IC-LhqFvSAmfE9oGVmnL7R4vfnxm_JA0V5k";
    const char* filepath = "/home/arch/Workspace/RustProjects/dianya_api_sdk/data/one_sentence.wav";
    const char* default_task_id = "tfile_e50e3ee3";
    
    // 示例 1: 上传音频文件（结构体返回）
    printf("示例 1: 上传音频文件\n");
    FfiUploadResponse upload_result = {0};
    FfiError error = {0};

    int code = transcribe_ffi_upload(
        filepath,
        0,  // transcribe_only = false
        0,  // short_asr = false
        "quality",
        token,
        &upload_result,
        &error
    );
    
    if (code != 0) {
        printf("%s\n", error.message);
        transcribe_ffi_free_upload_response(&upload_result);
        return 1;
    }
    
    if (!upload_result.is_normal) {
        printf("一句话转写模式:\n");
        printf("status: %s\n", upload_result.one_sentence.status);
        printf("message: %s\n", upload_result.one_sentence.message);
        printf("data: %s\n", upload_result.one_sentence.data);
        transcribe_ffi_free_upload_response(&upload_result);
        return 0;
    } else {
        printf("普通转写模式，任务ID: %s\n", upload_result.normal.task_id);
    }

    char task_id[256] = {0};
    strncpy(task_id, default_task_id, sizeof(task_id) - 1);
    transcribe_ffi_free_upload_response(&upload_result);
    
    if (strlen(task_id) > 0) {
        printf("任务ID: %s\n", task_id);
        
        // 示例 2: 获取状态
        printf("\n示例 2: 获取转写任务状态\n");
        FfiTranscribeStatus status_result = {0};
        
        code = transcribe_ffi_get_status(
            task_id,
            NULL,  // share_id
            token,
            &status_result,
            &error
        );
        
        if (code != 0) {
            printf("%s\n", error.message);
        } else {
            printf("状态: %s\n", status_result.status);
            if (status_result.overview_md) {
                printf("概览:\n%s\n", status_result.overview_md);
            }
            if (status_result.summary_md) {
                printf("总结:\n%s\n", status_result.summary_md);
            }
        }
        transcribe_ffi_free_transcribe_status(&status_result);
        
        // 示例 3: 获取分享链接
        printf("\n示例 3: 获取分享链接\n");
        FfiShareLink share_result = {0};
        
        code = transcribe_ffi_get_share_link(
            task_id,
            7,  // expiration_day
            token,
            &share_result,
            &error
        );
        
        if (code != 0) {
            printf("%s\n", error.message);
        } else {
            printf("分享链接: %s\n", share_result.share_url);
            printf("过期天数: %d\n", share_result.expiration_day);
            printf("过期时间: %s\n", share_result.expired_at);
        }
        transcribe_ffi_free_share_link(&share_result);
        
        // 示例 4: 导出转写结果
        printf("\n示例 4: 导出转写结果（二进制数据保持不变）\n");
        uint8_t export_data[1024 * 1024];  // 1MB 缓冲区
        size_t export_len = sizeof(export_data);
        
        code = transcribe_ffi_export(
            task_id,
            "transcript",
            "pdf",
            token,
            export_data,
            &export_len,
            &error
        );
        
        if (code != 0) {
            printf("%s\n", error.message);
        } else {
            printf("导出成功，数据大小: %zu 字节\n", export_len);
        }
        
        // 示例 5: 翻译转写任务
        printf("\n示例 5: 翻译转写任务（结构体返回）\n");
        FfiTranscribeTranslator translate_result = {0};
        
        code = transcribe_ffi_translate_transcribe(
            task_id,
            "en",  // target_lang
            token,
            &translate_result,
            &error
        );
        
        if (code != 0) {
            printf("%s\n", error.message);
        } else {
            printf("翻译任务状态: %s\n", translate_result.status);
            if (translate_result.overview_md) {
                printf("概览翻译:\n%s\n", translate_result.overview_md);
            }
        }
        transcribe_ffi_free_transcribe_translator(&translate_result);
    }
    
    // 示例 6: 翻译文本
    printf("\n示例 6: 翻译文本（结构体返回）\n");
    FfiTextTranslator text_result = {0};
    
    code = transcribe_ffi_translate_text(
        "Hello, world!",
        "zh",  // target_lang
        token,
        &text_result,
        &error
    );
    
    if (code != 0) {
        printf("%s\n", error.message);
    } else {
        printf("翻译状态: %s\n", text_result.status);
        printf("翻译内容: %s\n", text_result.data);
    }
    transcribe_ffi_free_text_translator(&text_result);
    
    // 示例 7: 创建实时转写会话
    printf("\n示例 7: 创建实时转写会话（结构体返回）\n");
    FfiSessionCreator session_result = {0};
    
    code = transcribe_ffi_create_session(
        "speed",
        token,
        &session_result,
        &error
    );
    
    if (code != 0) {
        printf("%s\n", error.message);
    } else {
        printf("会话任务ID: %s\n", session_result.task_id);
        printf("会话ID: %s\n", session_result.session_id);
        printf("最大转写时长: %d 秒\n", session_result.max_time);
    }
    transcribe_ffi_free_session_creator(&session_result);
    
    return 0;
}

