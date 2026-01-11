# frozen_string_literal: true

# Backward compatibility alias - OpenAI classes include this specific path
# The actual implementation is now in Provider::Concerns::UsageRecorder
module Provider::Openai::Concerns::UsageRecorder
  include Provider::Concerns::UsageRecorder
end
