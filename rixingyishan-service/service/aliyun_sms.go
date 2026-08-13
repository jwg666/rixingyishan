package service

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"

	openapi "github.com/alibabacloud-go/darabonba-openapi/v2/client"
	dysmsapi "github.com/alibabacloud-go/dysmsapi-20170525/v4/client"
	"github.com/alibabacloud-go/tea/tea"

	"rixingyishan-service/config"
)

// ---------- 阿里云短信发送 ----------

var (
	aliyunOnce    sync.Once
	aliyunClient  *dysmsapi.Client
	aliyunInitErr error
)

func getAliyunClient() (*dysmsapi.Client, error) {
	aliyunOnce.Do(func() {
		conf := &openapi.Config{
			AccessKeyId:     tea.String(config.AliyunAccessKeyID),
			AccessKeySecret: tea.String(config.AliyunAccessKeySecret),
			Endpoint:        tea.String("dysmsapi.aliyuncs.com"),
		}
		c, err := dysmsapi.NewClient(conf)
		if err != nil {
			aliyunInitErr = err
			return
		}
		aliyunClient = c
		log.Printf("[SMS] 阿里云短信客户端初始化完成 (签名=%s 模板=%s TTL=%s)",
			config.AliyunSMSSignName, config.AliyunSMSTemplateCode, config.SMSCodeTTL)
	})
	return aliyunClient, aliyunInitErr
}

// SendAliyunSMS 通过阿里云发送验证码短信，模板参数为 {"code": "xxxxxx"}
func SendAliyunSMS(phone, code string) error {
	cli, err := getAliyunClient()
	if err != nil {
		return fmt.Errorf("初始化阿里云客户端失败: %w", err)
	}

	param, _ := json.Marshal(map[string]string{"code": code})
	req := &dysmsapi.SendSmsRequest{
		PhoneNumbers:  tea.String(phone),
		SignName:      tea.String(config.AliyunSMSSignName),
		TemplateCode:  tea.String(config.AliyunSMSTemplateCode),
		TemplateParam: tea.String(string(param)),
	}

	resp, err := cli.SendSms(req)
	if err != nil {
		return err
	}
	if resp.Body == nil {
		return fmt.Errorf("阿里云返回为空")
	}
	if tea.StringValue(resp.Body.Code) != "OK" {
		return fmt.Errorf("阿里云短信发送失败: code=%s message=%s requestId=%s",
			tea.StringValue(resp.Body.Code), tea.StringValue(resp.Body.Message), tea.StringValue(resp.Body.RequestId))
	}
	log.Printf("[SMS] 验证码已发送至 %s (bizId=%s)", phone, tea.StringValue(resp.Body.BizId))
	return nil
}
