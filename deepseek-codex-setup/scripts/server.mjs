#!/usr/bin/env node
import http from "node:http";
import { randomUUID } from "node:crypto";

const HOST = process.env.DEEPSEEK_PROXY_HOST || "127.0.0.1";
const PORT = Number(process.env.DEEPSEEK_PROXY_PORT || 8766);
const DEEPSEEK_BASE_URL = process.env.DEEPSEEK_BASE_URL || "https://api.deepseek.com";
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;

if (!DEEPSEEK_API_KEY) {
  console.error("DEEPSEEK_API_KEY is required. Put it in ~/.codex/.env and source it before starting.");
  process.exit(1);
}

process.on("uncaughtException", (error) => {
  console.error("uncaughtException:", error?.stack || error);
});

process.on("unhandledRejection", (error) => {
  console.error("unhandledRejection:", error?.stack || error);
});

process.on("exit", (code) => {
  console.error(`process exit: ${code}`);
});

for (const signal of ["SIGPIPE", "SIGHUP"]) {
  process.on(signal, () => {
    console.error(`signal: ${signal} ignored`);
  });
}

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, () => {
    console.error(`signal: ${signal}`);
    process.exit(0);
  });
}

setInterval(() => {}, 60_000);

function readJson(request) {
  return new Promise((resolve, reject) => {
    let body = "";
    request.setEncoding("utf8");
    request.on("data", (chunk) => {
      body += chunk;
      if (body.length > 50 * 1024 * 1024) {
        reject(new Error("request body too large"));
        request.destroy();
      }
    });
    request.on("end", () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (error) {
        reject(error);
      }
    });
    request.on("error", reject);
  });
}

function contentToText(content) {
  if (typeof content === "string") {
    return content;
  }
  if (!Array.isArray(content)) {
    return "";
  }
  return content
    .map((part) => {
      if (typeof part === "string") {
        return part;
      }
      if (part?.type === "input_text" || part?.type === "output_text" || part?.type === "text") {
        return part.text || "";
      }
      return "";
    })
    .filter(Boolean)
    .join("\n");
}

function mapInputToMessages(input, instructions) {
  const messages = [];
  if (instructions) {
    messages.push({ role: "system", content: instructions });
  }

  for (const item of Array.isArray(input) ? input : []) {
    if (item?.type === "message") {
      const content = contentToText(item.content);
      if (!content) {
        continue;
      }
      const role = item.role === "assistant" ? "assistant" : item.role === "developer" ? "system" : "user";
      messages.push({ role, content });
      continue;
    }

    if (item?.type === "function_call") {
      messages.push({
        role: "assistant",
        content: null,
        tool_calls: [
          {
            id: item.call_id || item.id || `call_${randomUUID().replaceAll("-", "")}`,
            type: "function",
            function: {
              name: item.name,
              arguments: item.arguments || "{}",
            },
          },
        ],
      });
      continue;
    }

    if (item?.type === "function_call_output") {
      messages.push({
        role: "tool",
        tool_call_id: item.call_id,
        content: typeof item.output === "string" ? item.output : JSON.stringify(item.output ?? ""),
      });
    }
  }

  return messages;
}

function mapTools(tools) {
  return (Array.isArray(tools) ? tools : [])
    .filter((tool) => tool?.type === "function" && tool?.name)
    .map((tool) => ({
      type: "function",
      function: {
        name: tool.name,
        description: tool.description || "",
        parameters: tool.parameters || { type: "object", properties: {} },
      },
    }));
}

function responseSkeleton(requestBody, responseId, status = "in_progress", output = [], usage = null) {
  return {
    id: responseId,
    object: "response",
    created_at: Math.floor(Date.now() / 1000),
    status,
    error: null,
    incomplete_details: null,
    instructions: requestBody.instructions ?? null,
    max_output_tokens: requestBody.max_output_tokens ?? null,
    model: requestBody.model,
    output,
    parallel_tool_calls: requestBody.parallel_tool_calls ?? false,
    previous_response_id: requestBody.previous_response_id ?? null,
    reasoning: requestBody.reasoning ?? null,
    store: requestBody.store ?? false,
    temperature: requestBody.temperature ?? null,
    text: requestBody.text ?? { format: { type: "text" } },
    tool_choice: requestBody.tool_choice ?? "auto",
    tools: requestBody.tools ?? [],
    top_p: requestBody.top_p ?? null,
    truncation: requestBody.truncation ?? "disabled",
    usage,
    metadata: requestBody.metadata ?? null,
  };
}

function mapUsage(usage) {
  if (!usage) {
    return null;
  }
  const inputTokens = usage.prompt_tokens ?? usage.input_tokens ?? 0;
  const outputTokens = usage.completion_tokens ?? usage.output_tokens ?? 0;
  return {
    input_tokens: inputTokens,
    input_tokens_details: {
      cached_tokens: usage.prompt_tokens_details?.cached_tokens ?? usage.prompt_cache_hit_tokens ?? 0,
    },
    output_tokens: outputTokens,
    output_tokens_details: {
      reasoning_tokens: usage.completion_tokens_details?.reasoning_tokens ?? 0,
    },
    total_tokens: usage.total_tokens ?? inputTokens + outputTokens,
  };
}

function writeEvent(response, event) {
  response.write(`data: ${JSON.stringify(event)}\n\n`);
}

function createTextEvents(requestBody, responseId, text, sequenceNumber) {
  const itemId = `msg_${randomUUID().replaceAll("-", "")}`;
  const outputItem = {
    id: itemId,
    type: "message",
    status: "completed",
    role: "assistant",
    content: [{ type: "output_text", text, annotations: [] }],
  };
  return [
    {
      type: "response.output_item.added",
      response_id: responseId,
      output_index: 0,
      item: { ...outputItem, status: "in_progress", content: [] },
      sequence_number: sequenceNumber++,
    },
    {
      type: "response.content_part.added",
      response_id: responseId,
      item_id: itemId,
      output_index: 0,
      content_index: 0,
      part: { type: "output_text", text: "", annotations: [] },
      sequence_number: sequenceNumber++,
    },
    {
      type: "response.output_text.delta",
      response_id: responseId,
      item_id: itemId,
      output_index: 0,
      content_index: 0,
      delta: text,
      sequence_number: sequenceNumber++,
    },
    {
      type: "response.output_text.done",
      response_id: responseId,
      item_id: itemId,
      output_index: 0,
      content_index: 0,
      text,
      logprobs: [],
      sequence_number: sequenceNumber++,
    },
    {
      type: "response.content_part.done",
      response_id: responseId,
      item_id: itemId,
      output_index: 0,
      content_index: 0,
      part: { type: "output_text", text, annotations: [] },
      sequence_number: sequenceNumber++,
    },
    {
      type: "response.output_item.done",
      response_id: responseId,
      output_index: 0,
      item: outputItem,
      sequence_number: sequenceNumber++,
    },
  ];
}

function createToolEvents(responseId, toolCall, sequenceNumber) {
  const itemId = `fc_${randomUUID().replaceAll("-", "")}`;
  const callId = toolCall.id || `call_${randomUUID().replaceAll("-", "")}`;
  const args = toolCall.function?.arguments || "{}";
  const outputItem = {
    id: itemId,
    type: "function_call",
    status: "completed",
    call_id: callId,
    name: toolCall.function?.name,
    arguments: args,
  };
  return [
    {
      type: "response.output_item.added",
      response_id: responseId,
      output_index: 0,
      item: { ...outputItem, status: "in_progress", arguments: "" },
      sequence_number: sequenceNumber++,
    },
    {
      type: "response.function_call_arguments.delta",
      response_id: responseId,
      item_id: itemId,
      output_index: 0,
      call_id: callId,
      delta: args,
      sequence_number: sequenceNumber++,
    },
    {
      type: "response.function_call_arguments.done",
      response_id: responseId,
      item_id: itemId,
      output_index: 0,
      call_id: callId,
      name: toolCall.function?.name,
      arguments: args,
      sequence_number: sequenceNumber++,
    },
    {
      type: "response.output_item.done",
      response_id: responseId,
      output_index: 0,
      item: outputItem,
      sequence_number: sequenceNumber++,
    },
  ];
}

async function callDeepSeek(requestBody) {
  const tools = mapTools(requestBody.tools);
  const body = {
    model: requestBody.model || "deepseek-v4-pro",
    messages: mapInputToMessages(requestBody.input, requestBody.instructions),
    stream: false,
    max_tokens: requestBody.max_output_tokens || 4096,
    thinking: { type: "disabled" },
  };

  if (tools.length > 0) {
    body.tools = tools;
    body.tool_choice = requestBody.tool_choice === "required" ? "required" : "auto";
    body.parallel_tool_calls = false;
  }

  const upstream = await fetch(`${DEEPSEEK_BASE_URL}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${DEEPSEEK_API_KEY}`,
    },
    body: JSON.stringify(body),
  });

  const text = await upstream.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    throw new Error(`DeepSeek returned non-JSON ${upstream.status}: ${text.slice(0, 500)}`);
  }

  if (!upstream.ok) {
    throw new Error(`DeepSeek ${upstream.status}: ${json?.error?.message || text.slice(0, 500)}`);
  }

  return json;
}

async function handleResponses(request, response) {
  const requestBody = await readJson(request);
  const responseId = `resp_${randomUUID().replaceAll("-", "")}`;
  let sequenceNumber = 0;

  response.writeHead(200, {
    "Content-Type": "text/event-stream; charset=utf-8",
    "Cache-Control": "no-cache, no-transform",
    Connection: "keep-alive",
  });

  writeEvent(response, {
    type: "response.created",
    response: responseSkeleton(requestBody, responseId),
    sequence_number: sequenceNumber++,
  });

  writeEvent(response, {
    type: "response.in_progress",
    response: responseSkeleton(requestBody, responseId),
    sequence_number: sequenceNumber++,
  });

  try {
    const deepseek = await callDeepSeek(requestBody);
    const message = deepseek.choices?.[0]?.message || {};
    let output = [];
    let events = [];

    if (Array.isArray(message.tool_calls) && message.tool_calls.length > 0) {
      const toolCall = message.tool_calls[0];
      events = createToolEvents(responseId, toolCall, sequenceNumber);
      output = [events[events.length - 1].item];
    } else {
      const text = message.content || "";
      events = createTextEvents(requestBody, responseId, text, sequenceNumber);
      output = [events[events.length - 1].item];
    }

    for (const event of events) {
      sequenceNumber = event.sequence_number + 1;
      writeEvent(response, event);
    }

    writeEvent(response, {
      type: "response.completed",
      response: responseSkeleton(requestBody, responseId, "completed", output, mapUsage(deepseek.usage)),
      sequence_number: sequenceNumber++,
    });
  } catch (error) {
    writeEvent(response, {
      type: "response.failed",
      response: {
        ...responseSkeleton(requestBody, responseId, "failed"),
        error: { code: "deepseek_proxy_error", message: error.message, type: "server_error" },
      },
      sequence_number: sequenceNumber++,
    });
  }

  response.end("data: [DONE]\n\n");
}

const server = http.createServer(async (request, response) => {
  try {
    if (request.method === "GET" && request.url === "/health") {
      response.writeHead(200, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ ok: true, provider: "deepseek", base_url: DEEPSEEK_BASE_URL }));
      return;
    }

    if (request.method === "POST" && request.url === "/responses") {
      await handleResponses(request, response);
      return;
    }

    response.writeHead(404, { "Content-Type": "application/json" });
    response.end(JSON.stringify({ error: { message: "not found" } }));
  } catch (error) {
    response.writeHead(500, { "Content-Type": "application/json" });
    response.end(JSON.stringify({ error: { message: error.message } }));
  }
});

server.listen(PORT, HOST, () => {
  console.log(`DeepSeek Responses proxy listening on http://${HOST}:${PORT}`);
});
