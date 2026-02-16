export interface RequestTimerResult {
  name: string;
  duration: number;
  success: boolean;
  timestamp: number;
}

let requestResults: RequestTimerResult[] = [];

export const requestTimer = async <T>(name: string, fn: () => Promise<T>): Promise<T> => {
  const start = Date.now();
  let success = true;
  
  try {
    const result = await fn();
    return result;
  } catch (error) {
    success = false;
    throw error;
  } finally {
    const duration = Date.now() - start;
    const result: RequestTimerResult = {
      name,
      duration,
      success,
      timestamp: Date.now()
    };
    
    requestResults.push(result);
    console.log(`[API Timer] ${name}: ${duration}ms (${success ? '成功' : '失败'})`);
    
    // 当结果数量超过100时，清理旧数据
    if (requestResults.length > 100) {
      requestResults = requestResults.slice(-100);
    }
  }
};

export const getRequestResults = (): RequestTimerResult[] => {
  return requestResults;
};

export const clearRequestResults = (): void => {
  requestResults = [];
};

export const getRequestStats = () => {
  if (requestResults.length === 0) {
    return {
      totalRequests: 0,
      totalDuration: 0,
      averageDuration: 0,
      successRate: 0,
      slowRequests: []
    };
  }
  
  const totalRequests = requestResults.length;
  const totalDuration = requestResults.reduce((sum, r) => sum + r.duration, 0);
  const successCount = requestResults.filter(r => r.success).length;
  const slowRequests = requestResults.filter(r => r.duration > 1000);
  
  return {
    totalRequests,
    totalDuration,
    averageDuration: totalDuration / totalRequests,
    successRate: (successCount / totalRequests) * 100,
    slowRequests
  };
};
