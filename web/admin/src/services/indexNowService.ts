import axios from 'axios';

class IndexNowService {
  private config = {
    host: 'www.cryptobtc.xin',
    key: '402a4244ed30456bbd50a19f5a4f259b',
    keyLocation: 'https://www.cryptobtc.xin/402a4244ed30456bbd50a19f5a4f259b.txt',
    apiUrl: 'https://api.indexnow.org/IndexNow'
  };

  /**
   * 提交单个URL到IndexNow
   * @param url 要提交的URL
   * @returns 提交结果
   */
  async submitUrl(url: string) {
    try {
      const response = await axios.post(this.config.apiUrl, {
        host: this.config.host,
        key: this.config.key,
        keyLocation: this.config.keyLocation,
        urlList: [url]
      }, {
        headers: {
          'Content-Type': 'application/json'
        }
      });
      
      return {
        success: true,
        status: response.status,
        data: response.data
      };
    } catch (error: any) {
      console.error('IndexNow submission failed:', error.message);
      return {
        success: false,
        error: error.message,
        status: error.response?.status
      };
    }
  }

  /**
   * 批量提交URL到IndexNow
   * @param urls 要提交的URL数组
   * @returns 提交结果
   */
  async submitUrls(urls: string[]) {
    // 分批提交，每批最多5个URL
    const batchSize = 5;
    const results = [];
    
    for (let i = 0; i < urls.length; i += batchSize) {
      const batch = urls.slice(i, i + batchSize);
      const result = await this.submitUrlBatch(batch);
      results.push(result);
      // 避免请求过快
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    return results;
  }

  /**
   * 提交一批URL到IndexNow
   * @param urlList 要提交的URL数组
   * @returns 提交结果
   */
  private async submitUrlBatch(urlList: string[]) {
    try {
      const response = await axios.post(this.config.apiUrl, {
        host: this.config.host,
        key: this.config.key,
        keyLocation: this.config.keyLocation,
        urlList
      }, {
        headers: {
          'Content-Type': 'application/json'
        }
      });
      
      return {
        success: true,
        status: response.status,
        data: response.data,
        urls: urlList
      };
    } catch (error: any) {
      console.error('IndexNow batch submission failed:', error.message);
      return {
        success: false,
        error: error.message,
        status: error.response?.status,
        urls: urlList
      };
    }
  }

  /**
   * 构建文档URL
   * @param nodeId 文档ID
   * @returns 完整的文档URL
   */
  buildDocumentUrl(nodeId: string) {
    return `https://www.cryptobtc.xin/node/${nodeId}`;
  }

  /**
   * 构建文档URL数组
   * @param nodeIds 文档ID数组
   * @returns 完整的文档URL数组
   */
  buildDocumentUrls(nodeIds: string[]) {
    return nodeIds.map(id => this.buildDocumentUrl(id));
  }
}

export default new IndexNowService();
