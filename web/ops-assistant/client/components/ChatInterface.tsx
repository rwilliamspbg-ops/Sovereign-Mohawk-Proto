import React from 'react';
import { useCopilotChat } from '@copilotkit/react-core';

const ChatInterface: React.FC = () => {
  const { messages, isLoading, input, setInput, submit } = useCopilotChat();

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        backgroundColor: '#fff'
      }}
    >
      {/* Messages */}
      <div
        style={{
          flex: 1,
          overflowY: 'auto',
          padding: '20px',
          display: 'flex',
          flexDirection: 'column',
          gap: '12px'
        }}
      >
        {messages.length === 0 ? (
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              height: '100%',
              color: '#999',
              textAlign: 'center'
            }}
          >
            <div>
              <p style={{ fontSize: '18px', marginBottom: '8px' }}>Welcome! 👋</p>
              <p style={{ fontSize: '14px' }}>
                Ask me about cluster metrics, dashboard explanations, or incident analysis.
              </p>
            </div>
          </div>
        ) : (
          messages.map((msg, idx) => (
            <div
              key={idx}
              style={{
                display: 'flex',
                justifyContent: msg.role === 'user' ? 'flex-end' : 'flex-start'
              }}
            >
              <div
                style={{
                  maxWidth: '70%',
                  padding: '12px 16px',
                  borderRadius: '8px',
                  backgroundColor: msg.role === 'user' ? '#0066ff' : '#f0f0f0',
                  color: msg.role === 'user' ? '#fff' : '#333',
                  wordBreak: 'break-word'
                }}
              >
                <p style={{ margin: 0, fontSize: '14px' }}>{msg.content}</p>
              </div>
            </div>
          ))
        )}
        {isLoading && (
          <div
            style={{
              display: 'flex',
              gap: '4px',
              alignItems: 'center',
              color: '#999'
            }}
          >
            <div
              style={{
                width: '8px',
                height: '8px',
                borderRadius: '50%',
                backgroundColor: '#999',
                animation: 'pulse 1.5s ease-in-out infinite'
              }}
            />
            <span style={{ fontSize: '14px' }}>Assistant is thinking...</span>
          </div>
        )}
      </div>

      {/* Input */}
      <div
        style={{
          padding: '16px 20px',
          borderTop: '1px solid #e0e0e0',
          display: 'flex',
          gap: '8px'
        }}
      >
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyPress={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              submit();
            }
          }}
          placeholder="Ask about metrics, dashboards, or incidents..."
          style={{
            flex: 1,
            padding: '10px 12px',
            border: '1px solid #d0d0d0',
            borderRadius: '6px',
            fontSize: '14px',
            outline: 'none'
          }}
          disabled={isLoading}
        />
        <button
          onClick={() => submit()}
          disabled={isLoading || !input.trim()}
          style={{
            padding: '10px 16px',
            backgroundColor: '#0066ff',
            color: '#fff',
            border: 'none',
            borderRadius: '6px',
            cursor: isLoading ? 'default' : 'pointer',
            opacity: isLoading || !input.trim() ? 0.5 : 1,
            fontSize: '14px',
            fontWeight: '500'
          }}
        >
          Send
        </button>
      </div>

      <style>{`
        @keyframes pulse {
          0%, 100% { opacity: 0.6; }
          50% { opacity: 1; }
        }
      `}</style>
    </div>
  );
};

export default ChatInterface;
