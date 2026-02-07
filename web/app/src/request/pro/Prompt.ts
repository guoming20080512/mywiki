/* eslint-disable */
/* tslint:disable */
// @ts-nocheck
/*
 * ---------------------------------------------------------------
 * ## THIS FILE WAS GENERATED VIA SWAGGER-TYPESCRIPT-API        ##
 * ##                                                           ##
 * ## AUTHOR: acacode                                           ##
 * ## SOURCE: https://github.com/acacode/swagger-typescript-api ##
 * ---------------------------------------------------------------
 */

import httpRequest, { ContentType, RequestParams } from "./httpClient";
import {
  DomainCreatePromptReq,
  DomainPWResponse,
  DomainPrompt,
  GetApiProV1PromptParams,
} from "./types";

/**
 * @description Get all prompts
 *
 * @tags prompt
 * @name GetApiProV1Prompt
 * @summary Get all prompts
 * @request GET:/api/pro/v1/prompt
 * @response `200` `(DomainPWResponse & {
    data?: DomainPrompt,

})` OK
 */

export const getApiProV1Prompt = (
  query: GetApiProV1PromptParams,
  params: RequestParams = {},
) =>
  httpRequest<
    DomainPWResponse & {
      data?: DomainPrompt;
    }
  >({
    path: `/api/pro/v1/prompt`,
    method: "GET",
    query: query,
    type: ContentType.Json,
    format: "json",
    ...params,
  });

/**
 * @description Create a new prompt
 *
 * @tags prompt
 * @name PostApiProV1Prompt
 * @summary Create a new prompt
 * @request POST:/api/pro/v1/prompt
 * @response `200` `(DomainPWResponse & {
    data?: DomainPrompt,

})` OK
 */

export const postApiProV1Prompt = (
  req: DomainCreatePromptReq,
  params: RequestParams = {},
) =>
  httpRequest<
    DomainPWResponse & {
      data?: DomainPrompt;
    }
  >({
    path: `/api/pro/v1/prompt`,
    method: "POST",
    body: req,
    type: ContentType.Json,
    format: "json",
    ...params,
  });
